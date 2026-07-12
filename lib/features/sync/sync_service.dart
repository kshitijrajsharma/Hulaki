import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:drift/drift.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/capture/gps_gate.dart';
import 'package:hulaki/features/identity/admin_roles.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';
import 'package:hulaki/features/messaging/domain/message_payload.dart';
import 'package:hulaki/features/sync/blob_store.dart';
import 'package:hulaki/features/sync/group_cipher.dart';
import 'package:hulaki/features/sync/message_transport.dart';
import 'package:uuid/uuid.dart';

/// The outcome of verifying an envelope's author signature on ingest.
enum _AuthResult { ok, reject, unknownSigner }

/// Moves messages between the local store and the transport. Everything is
/// written locally first (the source of truth); the network is a courier that
/// runs when online and catches up on reconnect. The server only sees
/// ciphertext.
class SyncService {
  SyncService({
    required this.db,
    required this.transport,
    required this.blobStore,
    required this.currentUserId,
    required Future<IdentityKeys> Function() identity,
    Uuid? uuid,
    Duration minRetry = const Duration(seconds: 2),
  }) : _identityLoader = identity,
       _uuid = uuid ?? const Uuid(),
       _minRetry = minRetry,
       _retryDelay = minRetry;

  final LocalDatabase db;
  final MessageTransport transport;
  final BlobStore blobStore;
  final String currentUserId;
  final Future<IdentityKeys> Function() _identityLoader;
  final Uuid _uuid;
  IdentityKeys? _identity;

  /// The device identity, loaded once and cached, used to sign outgoing
  /// envelopes so ingest on other devices can prove authorship.
  Future<IdentityKeys> _deviceIdentity() async =>
      _identity ??= await _identityLoader();

  final Map<String, StreamSubscription<Envelope>> _subscriptions = {};
  final Set<String> _caughtUp = {};
  final Set<String> _syncing = {};
  final StreamController<Set<String>> _syncingController =
      StreamController<Set<String>>.broadcast();
  bool _online = true;
  bool _draining = false;
  bool _disposed = false;
  Future<void>? _drainDone;
  Future<void> _liveTail = Future<void>.value();
  Timer? _retryTimer;
  final Duration _minRetry;
  Duration _retryDelay;
  DateTime _lastEnqueue = DateTime.fromMillisecondsSinceEpoch(0);

  static const _maxRetry = Duration(minutes: 1);

  bool get isOnline => _online;

  /// The groups pulling their initial history, so a freshly joined thread can
  /// show a syncing state instead of looking empty.
  Stream<Set<String>> get syncingGroups => _syncingController.stream;

  void _markSyncing(String groupId, {required bool active}) {
    if (active) {
      _syncing.add(groupId);
    } else {
      _syncing.remove(groupId);
    }
    if (!_syncingController.isClosed) {
      _syncingController.add(Set.unmodifiable(_syncing));
    }
  }

  /// A strictly increasing enqueue timestamp, so outbox draining stays FIFO
  /// even for enqueues within the same millisecond.
  DateTime _nextEnqueueTime() {
    var now = DateTime.now();
    if (!now.isAfter(_lastEnqueue)) {
      now = _lastEnqueue.add(const Duration(milliseconds: 1));
    }
    _lastEnqueue = now;
    return now;
  }

  /// Flips connectivity. Going offline drops the live subscriptions; coming
  /// back drains the outbox, re-subscribes, and catches up every group,
  /// exactly as a returning network would.
  Future<void> setOnline({required bool value}) async {
    _online = value;
    if (!value) {
      _retryTimer?.cancel();
      _retryTimer = null;
      for (final sub in _subscriptions.values) {
        await sub.cancel();
      }
      _subscriptions.clear();
      _caughtUp.clear();
      return;
    }
    // A fresh reconnect should retry promptly, not at a backed-off delay.
    _retryDelay = _minRetry;
    await _drain();
    for (final group in await db.activeGroups()) {
      await start(group.id);
    }
  }

  /// Serialises live envelopes and records the tail, so concurrent ingests do
  /// not race on the cursor and dispose can await any still in flight before
  /// the database is closed. One failing ingest never breaks the chain.
  void _enqueueLive(Envelope envelope) {
    _liveTail = _liveTail
        .then((_) async {
          if (_disposed) return;
          await _ingest(envelope);
        })
        .catchError((Object error, StackTrace stack) {
          developer.log(
            'Live ingest failed',
            name: 'sync',
            error: error,
            stackTrace: stack,
          );
        });
  }

  /// Subscribes to live envelopes for a group and pulls anything missed.
  Future<void> start(String groupId) async {
    if (_disposed) return;
    _subscriptions[groupId] ??= transport
        .subscribe(groupId)
        .listen(_enqueueLive);
    _markSyncing(groupId, active: true);
    try {
      await catchUp(groupId);
    } finally {
      _markSyncing(groupId, active: false);
    }
  }

  Future<void> catchUp(String groupId) async {
    if (_disposed) return;
    final since = await db.cursorFor(groupId);
    final envelopes = await transport.fetchSince(groupId, since)
      // Apply strictly by seq: group-meta is last-writer-wins, so a transport
      // that returns rows in any other order must not decide which edit sticks.
      ..sort((a, b) => a.seq.compareTo(b.seq));
    for (final envelope in envelopes) {
      if (_disposed) return;
      // Stop if an author's key is not known yet: leave the cursor below this
      // envelope so the next catch-up resumes here, rather than skipping it.
      if (await _ingest(envelope, applyOwnMeta: true)) return;
    }
    // The group is now current: live envelopes may advance the cursor.
    _caughtUp.add(groupId);
  }

  /// Cancels a group's live subscription and forgets its catch-up state, so a
  /// later rejoin builds a fresh subscription and re-runs catch-up cleanly.
  Future<void> stop(String groupId) async {
    _caughtUp.remove(groupId);
    final sub = _subscriptions.remove(groupId);
    await sub?.cancel();
  }

  /// Deletes a group's stored envelopes on the server after tearing down its
  /// live subscription, so an admin's delete removes the data everywhere and no
  /// in-flight fan-out re-ingests it mid-purge.
  Future<void> purgeRemote(String groupId) async {
    await stop(groupId);
    // Remove the group's media blobs before its envelopes, so a purged group
    // leaves nothing downloadable on the server.
    for (final message in await db.messagesFor(groupId)) {
      final mediaId = message.mediaId;
      if (mediaId != null && mediaId.isNotEmpty) {
        await blobStore.remove(mediaId);
      }
    }
    await transport.purgeGroup(groupId);
  }

  /// Re-fetches a group's whole history from the start and re-ingests it,
  /// reconciling any hole left when the cursor advanced past messages that were
  /// never stored. Ingest is idempotent, so this adds only what is missing.
  Future<void> resync(String groupId) async {
    _markSyncing(groupId, active: true);
    try {
      final envelopes = await transport.fetchSince(groupId, 0)
        ..sort((a, b) => a.seq.compareTo(b.seq));
      for (final envelope in envelopes) {
        if (await _ingest(envelope, applyOwnMeta: true)) return;
      }
    } finally {
      _markSyncing(groupId, active: false);
    }
  }

  Future<String> sendText({
    required String groupId,
    String? text,
    String? tagId,
    GeoResult? geo,
    String? replyToId,
    String? senderName,
    bool anonymous = false,
    DateTime? at,
  }) {
    return _enqueueCreate(
      groupId: groupId,
      kind: MessageKind.text,
      body: text,
      tagId: tagId,
      geo: geo,
      replyToId: replyToId,
      senderName: senderName,
      anonymous: anonymous,
      at: at,
    );
  }

  Future<String> sendPhoto({
    required String groupId,
    required Uint8List bytes,
    String mime = 'image/jpeg',
    String? caption,
    String? tagId,
    GeoResult? geo,
    String? replyToId,
    String? senderName,
    bool anonymous = false,
    DateTime? at,
  }) async {
    final mediaId = _uuid.v4();
    final mediaKey = await GroupCipher.generateKey();
    await db
        .into(db.mediaBlobs)
        .insert(
          MediaBlobsCompanion.insert(id: mediaId, bytes: bytes, mime: mime),
          mode: InsertMode.insertOrReplace,
        );
    return _enqueueCreate(
      groupId: groupId,
      kind: MessageKind.photo,
      body: caption,
      tagId: tagId,
      geo: geo,
      replyToId: replyToId,
      senderName: senderName,
      anonymous: anonymous,
      at: at,
      mediaId: mediaId,
      mediaMime: mime,
      mediaKeyB64: base64Encode(mediaKey),
    );
  }

  Future<void> editMessage({
    required String messageId,
    required String newBody,
  }) async {
    final row = await _rowById(messageId);
    if (row == null) return;
    final edited = DateTime.now();
    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(body: Value(newBody), editedAt: Value(edited)),
    );
    final updated = await _rowById(messageId);
    await _enqueuePayload(_payloadFromRow(updated!));
  }

  /// Re-tags a point, or clears its tag when [tagId] is null, and propagates
  /// the change like an edit so every member re-colours the marker.
  Future<void> setMessageTag({
    required String messageId,
    required String? tagId,
  }) async {
    final row = await _rowById(messageId);
    if (row == null) return;
    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(tagId: Value(tagId), editedAt: Value(DateTime.now())),
    );
    final updated = await _rowById(messageId);
    await _enqueuePayload(_payloadFromRow(updated!));
  }

  Future<void> deleteMessage(String messageId) async {
    final row = await _rowById(messageId);
    if (row == null) return;
    final deleted = DateTime.now();
    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(deletedAt: Value(deleted)),
    );
    final updated = await _rowById(messageId);
    await _enqueuePayload(_payloadFromRow(updated!));
    // Drop the media blob too, so a deleted photo does not stay downloadable.
    final mediaId = row.mediaId;
    if (mediaId != null && mediaId.isNotEmpty) {
      await blobStore.remove(mediaId);
    }
  }

  /// Publishes group metadata (name, hot-keys, area) so members joining by
  /// link receive it through the same encrypted pipeline.
  Future<void> publishGroupMeta({
    required String groupId,
    required Map<String, dynamic> meta,
    String? photoBlobId,
    String? photoKeyB64,
    DateTime? at,
  }) async {
    final createdAt = at ?? DateTime.now();
    final payload = MessagePayload(
      id: _uuid.v4(),
      groupId: groupId,
      senderId: currentUserId,
      kind: MessageKind.groupMeta,
      createdAtMs: createdAt.millisecondsSinceEpoch,
      body: jsonEncode(meta),
      // The cover photo rides the same encrypted blob path as message media:
      // the drain uploads it, a receiving device fetches it in _applyGroupMeta.
      mediaId: photoBlobId,
      mediaMime: photoBlobId == null ? null : 'image/jpeg',
      mediaKeyB64: photoKeyB64,
    );
    await _enqueuePayload(payload);
  }

  /// Publishes a control message (identity announce or an admin handshake
  /// event) through the encrypted pipeline. Returns the message id so the
  /// author can apply it locally, since own messages are not re-ingested.
  Future<String> publishControl({
    required String groupId,
    required MessageKind kind,
    required Map<String, dynamic> body,
    DateTime? at,
  }) async {
    final payload = MessagePayload(
      id: _uuid.v4(),
      groupId: groupId,
      senderId: currentUserId,
      kind: kind,
      createdAtMs: (at ?? DateTime.now()).millisecondsSinceEpoch,
      body: jsonEncode(body),
    );
    await _enqueuePayload(payload);
    return payload.id;
  }

  Future<String> _enqueueCreate({
    required String groupId,
    required MessageKind kind,
    String? body,
    String? tagId,
    GeoResult? geo,
    String? replyToId,
    String? senderName,
    bool anonymous = false,
    DateTime? at,
    String? mediaId,
    String? mediaMime,
    String? mediaKeyB64,
  }) async {
    final createdAt = at ?? DateTime.now();
    final payload = MessagePayload(
      id: _uuid.v4(),
      groupId: groupId,
      senderId: currentUserId,
      kind: kind,
      createdAtMs: createdAt.millisecondsSinceEpoch,
      senderName: senderName,
      anonymous: anonymous,
      body: body,
      tagId: tagId,
      lat: geo?.lat,
      lng: geo?.lng,
      accuracyM: geo?.accuracyM,
      altitudeM: geo?.altitudeM,
      headingDeg: geo?.headingDeg,
      locationPending: geo?.pending ?? false,
      mediaId: mediaId,
      mediaMime: mediaMime,
      mediaKeyB64: mediaKeyB64,
      replyToId: replyToId,
    );
    await _applyLocal(payload, sendState: 'pending');
    await _enqueuePayload(payload);
    return payload.id;
  }

  Future<void> _enqueuePayload(MessagePayload payload) async {
    await db.enqueueOutbox(
      OutboxData(
        id: _uuid.v4(),
        groupId: payload.groupId,
        messageId: payload.id,
        payloadJson: jsonEncode(payload.toJson()),
        // Enqueue time, not the message's created-at, so a create always
        // drains before a later edit/delete of the same message.
        createdAt: _nextEnqueueTime(),
      ),
    );
    if (_online) await _drain();
  }

  Future<void> _drain() async {
    if (_draining || _disposed) return;
    _draining = true;
    final completer = Completer<void>();
    _drainDone = completer.future;
    try {
      // Re-check the outbox after each pass. Entries enqueued while this drain
      // was running are sent here rather than waiting for the next trigger.
      // Stop once a pass sends nothing, so a down transport does not spin; the
      // backoff timer retries instead.
      var progressed = true;
      while (progressed && !_disposed) {
        progressed = false;
        final entries = await db.outboxEntries();
        if (entries.isEmpty) break;
        for (final entry in entries) {
          if (_disposed) break;
          final key = await _groupKey(entry.groupId);
          if (key == null) {
            // The group is gone; the entry can never publish, so drop it.
            await db.deleteOutbox(entry.id);
            progressed = true;
            continue;
          }
          try {
            await _drainEntry(entry, key);
            progressed = true;
          } on Exception {
            // A transport, storage or encoding failure on one entry must not
            // block the rest. Leave it queued for the backoff retry.
            continue;
          }
        }
      }
    } finally {
      _draining = false;
      completer.complete();
    }
    await _scheduleRetryIfPending();
  }

  /// Arms a backoff retry when the outbox still holds entries after a drain, so
  /// a send that failed (offline, or a flaky transport) is retried instead of
  /// sitting on "pending" forever. Clears once the outbox drains.
  Future<void> _scheduleRetryIfPending() async {
    if (_disposed) return;
    final pending = await db.outboxEntries();
    if (pending.isEmpty || !_online) {
      _retryDelay = _minRetry;
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    if (_retryTimer != null) return;
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      final next = _retryDelay * 2;
      _retryDelay = next < _maxRetry ? next : _maxRetry;
      unawaited(_drain());
    });
  }

  Future<void> _drainEntry(OutboxData entry, Uint8List key) async {
    final payload = MessagePayload.fromJson(
      jsonDecode(entry.payloadJson) as Map<String, dynamic>,
    );

    final mediaId = payload.mediaId;
    if (mediaId != null &&
        payload.mediaKeyB64 != null &&
        await blobStore.get(mediaId) == null) {
      final plaintext = await db.mediaBytes(mediaId);
      if (plaintext != null) {
        final cipher = await GroupCipher.encryptBytes(
          plaintext,
          base64Decode(payload.mediaKeyB64!),
        );
        await blobStore.put(mediaId, cipher);
      }
    }

    // Sign the payload so ingest on other devices can prove this author and
    // reject anything spoofed or injected by a non-member.
    final identity = await _deviceIdentity();
    final signed = payload.toJson()
      ..['sig'] = base64Encode(await identity.sign(payload.bytesToSign()));
    final ciphertext = await GroupCipher.encryptJson(signed, key);
    final seq = await transport.publish(
      Envelope(
        groupId: payload.groupId,
        messageId: payload.id,
        senderId: currentUserId,
        ciphertext: ciphertext,
        senderPubkey: base64Encode(identity.signingPublic),
      ),
    );
    if (payload.kind != MessageKind.groupMeta) {
      await (db.update(
        db.messages,
      )..where((m) => m.id.equals(payload.id))).write(
        MessagesCompanion(
          sendState: const Value('sent'),
          remoteSeq: Value(seq),
        ),
      );
    }
    await db.deleteOutbox(entry.id);
  }

  /// Applies one envelope. Returns true when the author's signing key is not
  /// known yet, so the caller must stop and not advance past this seq (a later
  /// pass re-runs it with the key known); false otherwise.
  Future<bool> _ingest(Envelope envelope, {bool applyOwnMeta = false}) async {
    if (_disposed) return false;
    // Process (decrypt + persist) before advancing the cursor. A transient
    // failure (no key yet, or a persist error) throws and holds the cursor so
    // catch-up retries the envelope; only a permanently undecryptable row is
    // dropped so it cannot wedge the group forever.
    final key = await _groupKey(envelope.groupId);
    if (key == null && envelope.senderId != currentUserId) {
      return false; // no group key yet: retry, do not advance.
    }
    if (key != null) {
      final payload = await _tryDecrypt(envelope, key);
      if (payload != null) {
        final auth = await _verifyAuthor(payload);
        // The author's key has not arrived yet (its announce is still ahead in
        // seq). Signal a hold so the caller stops before advancing past it,
        // rather than letting a later envelope skip it.
        if (auth == _AuthResult.unknownSigner) return true;
        if (auth == _AuthResult.ok) {
          final mine = payload.senderId == currentUserId;
          final isMeta = payload.kind == MessageKind.groupMeta;
          // Own envelopes are reapplied only during catch-up, so a rejoined
          // device restores its own tags, settings and points. The live path
          // skips them so a returning echo cannot clobber fresh local state.
          final apply = !mine || applyOwnMeta;
          if (isMeta && apply) {
            if (await _metaAuthorized(payload)) {
              await _applyGroupMeta(payload);
            } else {
              developer.log(
                'Dropping group-meta from non-admin ${payload.senderId} '
                'in ${payload.groupId}',
                name: 'sync',
              );
            }
          } else if (!isMeta && apply) {
            await _ingestFromOther(payload, envelope);
          }
        }
        // A rejected (unsigned, mis-signed, or identity-swapping) envelope
        // falls through and the cursor advances, dropping it.
      }
    }

    // Hold the cursor until the first catch-up for this group finishes. A live
    // envelope arriving mid-join must not advance it past the group-meta, or
    // catch-up's fetchSince would skip the tags, area and points on a rejoin.
    final advance = applyOwnMeta || _caughtUp.contains(envelope.groupId);
    final current = await db.cursorFor(envelope.groupId);
    if (advance && envelope.seq > current) {
      await db.setCursor(envelope.groupId, envelope.seq);
    }
    return false;
  }

  /// Decrypts one envelope, or returns null for a row that cannot be
  /// authenticated or parsed under the group key. The relay accepts inserts
  /// from any signed-in device, so a corrupt or hostile row can appear.
  /// Dropping just that one (and letting the cursor advance past it) keeps a
  /// single poison envelope from wedging the group's catch-up for every member.
  Future<MessagePayload?> _tryDecrypt(Envelope envelope, Uint8List key) async {
    try {
      return MessagePayload.fromJson(
        await GroupCipher.decryptJson(envelope.ciphertext, key),
      );
    } on SecretBoxAuthenticationError catch (error) {
      developer.log(
        'Dropping unauthenticated envelope in ${envelope.groupId}',
        name: 'sync',
        error: error,
      );
    } on FormatException catch (error) {
      developer.log(
        'Dropping malformed envelope in ${envelope.groupId}',
        name: 'sync',
        error: error,
      );
    }
    return null;
  }

  /// Checks that an envelope's signature proves its claimed sender, so a member
  /// key holder cannot forge another author and a non-member cannot inject at
  /// all. Returns `unknownSigner` when the author's key is not known yet
  /// (transient: hold and retry), and `reject` for an unsigned, mis-signed, or
  /// identity-swapping envelope (drop it).
  Future<_AuthResult> _verifyAuthor(MessagePayload payload) async {
    final sig = payload.sig;
    if (sig == null) {
      developer.log(
        'Dropping unsigned envelope in ${payload.groupId}',
        name: 'sync',
      );
      return _AuthResult.reject;
    }
    if (payload.kind == MessageKind.identityAnnounce) {
      return _verifyAnnounce(payload, sig);
    }
    final knownKey = (await db.profileById(payload.senderId))?.signingKey;
    if (knownKey == null) return _AuthResult.unknownSigner;
    return await _verifySig(payload, sig, knownKey)
        ? _AuthResult.ok
        : _AuthResult.reject;
  }

  /// An announce is self-signed: it proves possession of the key it carries.
  /// Trust on first use anchors that key to the sender id, so a later announce
  /// may not swap it and no one can hijack another member's id.
  Future<_AuthResult> _verifyAnnounce(
    MessagePayload payload,
    String sig,
  ) async {
    final body = jsonDecode(payload.body ?? '{}') as Map<String, dynamic>;
    final announced = body['signingKey'] as String?;
    if (announced == null || !(await _verifySig(payload, sig, announced))) {
      developer.log(
        'Dropping unverifiable announce from ${payload.senderId}',
        name: 'sync',
      );
      return _AuthResult.reject;
    }
    final existing = (await db.profileById(payload.senderId))?.signingKey;
    if (existing != null && existing != announced) {
      developer.log(
        'Rejecting announce that changes the key for ${payload.senderId}',
        name: 'sync',
      );
      return _AuthResult.reject;
    }
    return _AuthResult.ok;
  }

  Future<bool> _verifySig(
    MessagePayload payload,
    String sig,
    String signerKeyB64,
  ) {
    return IdentityKeys.verify(
      payload.bytesToSign(),
      signature: base64Decode(sig),
      signerPublic: base64Decode(signerKeyB64),
    );
  }

  /// Applies an envelope authored by another member: a control message, an
  /// identity announce, or a chat observation with any referenced media blob.
  Future<void> _ingestFromOther(
    MessagePayload payload,
    Envelope envelope,
  ) async {
    if (payload.kind == MessageKind.identityAnnounce) {
      await _applyIdentityAnnounce(payload);
    } else if (payload.kind == MessageKind.adminInvite ||
        payload.kind == MessageKind.adminAccept) {
      await _applyAdminEventPayload(payload, seq: envelope.seq);
    } else {
      final name = payload.senderName;
      if (name != null && name.isNotEmpty) {
        final existing = await db.profileById(envelope.senderId);
        if (existing?.displayName != name) {
          await db.upsertProfile(
            ProfilesCompanion.insert(
              id: envelope.senderId,
              phone: '',
              displayName: Value(name),
            ),
          );
        }
      }
      await _recordMember(payload.groupId, envelope.senderId);
      final mediaId = payload.mediaId;
      if (mediaId != null &&
          payload.mediaKeyB64 != null &&
          await db.mediaBytes(mediaId) == null) {
        final cipher = await blobStore.get(mediaId);
        if (cipher != null) {
          final clear = await GroupCipher.decryptBytes(
            cipher,
            base64Decode(payload.mediaKeyB64!),
          );
          await db
              .into(db.mediaBlobs)
              .insert(
                MediaBlobsCompanion.insert(
                  id: mediaId,
                  bytes: clear,
                  mime: payload.mediaMime ?? 'application/octet-stream',
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      }
      await _applyLocal(payload, sendState: 'sent', remoteSeq: envelope.seq);
    }
  }

  /// Records a member's public keys and name so they can be promoted and, once
  /// public keys are known, be sealed the group key at approval time.
  Future<void> _applyIdentityAnnounce(MessagePayload payload) async {
    final body = jsonDecode(payload.body ?? '{}') as Map<String, dynamic>;
    await db.upsertProfile(
      ProfilesCompanion.insert(
        id: payload.senderId,
        phone: '',
        displayName: Value(body['username'] as String?),
        signingKey: Value(body['signingKey'] as String?),
        agreementKey: Value(body['agreementKey'] as String?),
      ),
    );
    await _recordMember(payload.groupId, payload.senderId);
  }

  /// Adds a participant to the local roster so admins can see and promote them.
  /// insertOrIgnore never downgrades an existing admin row.
  Future<void> _recordMember(String groupId, String profileId) => db
      .into(db.groupMembers)
      .insert(
        GroupMembersCompanion.insert(groupId: groupId, profileId: profileId),
        mode: InsertMode.insertOrIgnore,
      );

  /// Stores a signed handshake event, then recomputes the verified admin set.
  Future<void> _applyAdminEventPayload(
    MessagePayload payload, {
    required int seq,
  }) async {
    final body = jsonDecode(payload.body ?? '{}') as Map<String, dynamic>;
    final subjectPublic = body['subjectPublic'] as String?;
    await applyAdminEvent(
      db,
      id: payload.id,
      groupId: payload.groupId,
      seq: seq,
      kind: payload.kind == MessageKind.adminInvite ? 'invite' : 'accept',
      actorId: payload.senderId,
      actorPublic: base64Decode(body['actorPublic'] as String),
      subjectId: body['subjectId'] as String,
      subjectPublic: subjectPublic == null ? null : base64Decode(subjectPublic),
      signature: base64Decode(body['signature'] as String),
    );
  }

  /// Whether [payload]'s author may change group metadata. The earliest meta
  /// (lowest seq) pins the admin root, so before a root exists any signed meta
  /// is accepted to establish the creator; after that only a verified admin
  /// may edit. Applying strictly by seq guarantees the bootstrap meta is the
  /// creator's, not a later member's.
  Future<bool> _metaAuthorized(MessagePayload payload) async {
    final group = await db.groupById(payload.groupId);
    if (group?.adminRootKey == null) return true;
    final admins = await recomputeAdmins(db, payload.groupId);
    return admins.contains(payload.senderId);
  }

  Future<void> _applyGroupMeta(MessagePayload payload) async {
    final meta = jsonDecode(payload.body ?? '{}') as Map<String, dynamic>;
    final existing = await db.groupById(payload.groupId);
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion(
            id: Value(payload.groupId),
            name: Value(meta['name'] as String? ?? existing?.name ?? ''),
            description: Value(meta['description'] as String?),
            createdBy: Value(payload.senderId),
            encKey: Value(existing?.encKey ?? ''),
            aoiGeoJson: Value(meta['aoiGeoJson'] as String?),
            isPublic: Value(meta['isPublic'] as bool? ?? false),
            joinApproval: Value(meta['joinApproval'] as bool? ?? false),
            allowMemberExport: Value(
              meta['allowMemberExport'] as bool? ?? false,
            ),
            allowMemberPlace: Value(
              meta['allowMemberPlace'] as bool? ?? true,
            ),
            allowOutsideArea: Value(
              meta['allowOutsideArea'] as bool? ?? true,
            ),
            gpsLimitM: Value((meta['gpsLimitM'] as num?)?.toInt()),
            allowMemberTags: Value(
              meta['allowMemberTags'] as bool? ?? false,
            ),
          ),
          onConflict: DoUpdate(
            (_) => GroupsCompanion(
              // Keep the existing name if the metadata omits one.
              name: meta['name'] != null
                  ? Value(meta['name'] as String)
                  : const Value.absent(),
              description: Value(meta['description'] as String?),
              aoiGeoJson: Value(meta['aoiGeoJson'] as String?),
              isPublic: Value(meta['isPublic'] as bool? ?? false),
              joinApproval: Value(meta['joinApproval'] as bool? ?? false),
              allowMemberExport: Value(
                meta['allowMemberExport'] as bool? ?? false,
              ),
              allowMemberPlace: Value(
                meta['allowMemberPlace'] as bool? ?? true,
              ),
              allowOutsideArea: Value(
                meta['allowOutsideArea'] as bool? ?? true,
              ),
              gpsLimitM: Value((meta['gpsLimitM'] as num?)?.toInt()),
              allowMemberTags: Value(
                meta['allowMemberTags'] as bool? ?? false,
              ),
            ),
          ),
        );

    // Pin the admin root the first time we learn it, and record the creator's
    // public keys. The earliest meta (lowest seq) is the creator's, so a later
    // member cannot hijack the root.
    final rootKey = meta['adminRootKey'] as String?;
    if (rootKey != null && (existing?.adminRootKey == null)) {
      await (db.update(
        db.groups,
      )..where((g) => g.id.equals(payload.groupId))).write(
        GroupsCompanion(
          adminRootKey: Value(rootKey),
          createdBy: Value(payload.senderId),
        ),
      );
      await db.upsertProfile(
        ProfilesCompanion.insert(
          id: payload.senderId,
          phone: '',
          displayName: Value(meta['creatorName'] as String?),
          signingKey: Value(rootKey),
          agreementKey: Value(meta['creatorAgreementKey'] as String?),
        ),
      );
    }
    await recomputeAdmins(db, payload.groupId);
    final hotKeys = (meta['hotKeys'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final keptIds = <String>{};
    for (final hk in hotKeys) {
      final id = hk['id'] as String;
      keptIds.add(id);
      await db
          .into(db.hotKeys)
          .insert(
            HotKeysCompanion.insert(
              id: id,
              groupId: payload.groupId,
              label: hk['label'] as String,
              colorValue: hk['colorValue'] as int,
              iconName: Value(hk['iconName'] as String?),
              position: Value(hk['position'] as int? ?? 0),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    // Prune hot-keys the admin removed so they stop appearing for members.
    for (final row in await db.hotKeysFor(payload.groupId)) {
      if (!keptIds.contains(row.id)) {
        await (db.delete(db.hotKeys)..where((h) => h.id.equals(row.id))).go();
      }
    }

    await _applyGroupPhoto(payload);
  }

  /// Fetches the shared cover photo a meta references, when this device lacks
  /// that blob. Applying is additive: a meta that carries no photo
  /// leaves the current one untouched, so a republish from a member who never
  /// downloaded it cannot wipe everyone's photo.
  Future<void> _applyGroupPhoto(MessagePayload payload) async {
    final blobId = payload.mediaId;
    final keyB64 = payload.mediaKeyB64;
    if (blobId == null || keyB64 == null) return;
    final current = await db.groupById(payload.groupId);
    if (current?.photoBlobId == blobId) return;
    final cipher = await blobStore.get(blobId);
    if (cipher == null) return;
    final clear = await GroupCipher.decryptBytes(cipher, base64Decode(keyB64));
    await (db.update(
      db.groups,
    )..where((g) => g.id.equals(payload.groupId))).write(
      GroupsCompanion(
        photo: Value(clear),
        photoBlobId: Value(blobId),
        photoKey: Value(keyB64),
      ),
    );
  }

  Future<void> _applyLocal(
    MessagePayload payload, {
    required String sendState,
    int? remoteSeq,
  }) async {
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: payload.id,
            groupId: payload.groupId,
            senderId: payload.senderId,
            kind: payload.kind.name,
            body: Value(payload.body),
            tagId: Value(payload.tagId),
            lat: Value(payload.lat),
            lng: Value(payload.lng),
            accuracyM: Value(payload.accuracyM),
            altitudeM: Value(payload.altitudeM),
            headingDeg: Value(payload.headingDeg),
            locationPending: Value(payload.locationPending),
            mediaId: Value(payload.mediaId),
            mediaMime: Value(payload.mediaMime),
            mediaKey: Value(payload.mediaKeyB64),
            replyToId: Value(payload.replyToId),
            createdAt: DateTime.fromMillisecondsSinceEpoch(payload.createdAtMs),
            editedAt: Value(
              payload.editedAtMs == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(payload.editedAtMs!),
            ),
            deletedAt: Value(
              payload.deletedAtMs == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(payload.deletedAtMs!),
            ),
            sendState: Value(sendState),
            remoteSeq: Value(remoteSeq),
            anonymous: Value(payload.anonymous),
          ),
          onConflict: DoUpdate(
            (_) => MessagesCompanion(
              body: Value(payload.body),
              editedAt: Value(
                payload.editedAtMs == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(payload.editedAtMs!),
              ),
              deletedAt: Value(
                payload.deletedAtMs == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(payload.deletedAtMs!),
              ),
              sendState: Value(sendState),
              remoteSeq: Value(remoteSeq),
            ),
          ),
        );
  }

  MessagePayload _payloadFromRow(Message row) => MessagePayload(
    id: row.id,
    groupId: row.groupId,
    senderId: row.senderId,
    kind: MessageKind.values.byName(row.kind),
    createdAtMs: row.createdAt.millisecondsSinceEpoch,
    anonymous: row.anonymous,
    body: row.body,
    tagId: row.tagId,
    lat: row.lat,
    lng: row.lng,
    accuracyM: row.accuracyM,
    locationPending: row.locationPending,
    mediaId: row.mediaId,
    mediaMime: row.mediaMime,
    mediaKeyB64: row.mediaKey,
    replyToId: row.replyToId,
    editedAtMs: row.editedAt?.millisecondsSinceEpoch,
    deletedAtMs: row.deletedAt?.millisecondsSinceEpoch,
  );

  Future<Message?> _rowById(String id) =>
      (db.select(db.messages)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<Uint8List?> _groupKey(String groupId) async {
    final group = await db.groupById(groupId);
    if (group == null || group.encKey.isEmpty) return null;
    try {
      return base64Decode(group.encKey);
    } on FormatException {
      // The key came from an invite link, which is external input. A malformed
      // key means this group can never be en/decrypted, so treat it as having
      // no usable key rather than crashing the whole drain.
      return null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    // Let an in-flight drain finish its current write before the caller closes
    // the database, so a detached publish never lands after teardown.
    await _drainDone;
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    // No new live envelopes can arrive now; wait for any still being ingested
    // so none touches the database after the caller closes it.
    await _liveTail;
    await _syncingController.close();
  }
}
