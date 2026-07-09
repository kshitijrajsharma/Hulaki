import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/identity/admin_roles.dart';
import 'package:fieldchat/features/messaging/domain/message_payload.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/group_cipher.dart';
import 'package:fieldchat/features/sync/message_transport.dart';
import 'package:uuid/uuid.dart';

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
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final LocalDatabase db;
  final MessageTransport transport;
  final BlobStore blobStore;
  final String currentUserId;
  final Uuid _uuid;

  final Map<String, StreamSubscription<Envelope>> _subscriptions = {};
  final Set<String> _syncing = {};
  final StreamController<Set<String>> _syncingController =
      StreamController<Set<String>>.broadcast();
  bool _online = true;
  bool _draining = false;
  bool _disposed = false;
  Future<void>? _drainDone;
  DateTime _lastEnqueue = DateTime.fromMillisecondsSinceEpoch(0);

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
      for (final sub in _subscriptions.values) {
        await sub.cancel();
      }
      _subscriptions.clear();
      return;
    }
    await _drain();
    for (final group in await db.activeGroups()) {
      await start(group.id);
    }
  }

  /// Subscribes to live envelopes for a group and pulls anything missed.
  Future<void> start(String groupId) async {
    _subscriptions[groupId] ??= transport
        .subscribe(groupId)
        .listen((envelope) => unawaited(_ingest(envelope)));
    _markSyncing(groupId, active: true);
    try {
      await catchUp(groupId);
    } finally {
      _markSyncing(groupId, active: false);
    }
  }

  Future<void> catchUp(String groupId) async {
    final since = await db.cursorFor(groupId);
    final envelopes = await transport.fetchSince(groupId, since);
    for (final envelope in envelopes) {
      await _ingest(envelope, applyOwnMeta: true);
    }
  }

  /// Re-fetches a group's whole history from the start and re-ingests it,
  /// reconciling any hole left when the cursor advanced past messages that were
  /// never stored. Ingest is idempotent, so this adds only what is missing.
  Future<void> resync(String groupId) async {
    _markSyncing(groupId, active: true);
    try {
      final envelopes = await transport.fetchSince(groupId, 0);
      for (final envelope in envelopes) {
        await _ingest(envelope, applyOwnMeta: true);
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

  Future<void> deleteMessage(String messageId) async {
    final row = await _rowById(messageId);
    if (row == null) return;
    final deleted = DateTime.now();
    await (db.update(db.messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(deletedAt: Value(deleted)),
    );
    final updated = await _rowById(messageId);
    await _enqueuePayload(_payloadFromRow(updated!));
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
      for (final entry in await db.outboxEntries()) {
        if (_disposed) break;
        final key = await _groupKey(entry.groupId);
        if (key == null) {
          // The group is gone; the entry can never publish, so drop it.
          await db.deleteOutbox(entry.id);
          continue;
        }
        try {
          await _drainEntry(entry, key);
        } on Exception {
          // A transport, storage or encoding failure on one entry must not
          // block the rest. Leave it queued and retry on the next drain.
          continue;
        }
      }
    } finally {
      _draining = false;
      completer.complete();
    }
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

    final ciphertext = await GroupCipher.encryptJson(payload.toJson(), key);
    final seq = await transport.publish(
      Envelope(
        groupId: payload.groupId,
        messageId: payload.id,
        senderId: currentUserId,
        ciphertext: ciphertext,
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

  Future<void> _ingest(Envelope envelope, {bool applyOwnMeta = false}) async {
    // Process (decrypt + persist) before advancing the cursor. If anything
    // throws, the cursor stays put so catch-up retries this envelope rather
    // than skipping it and losing the observation for good.
    final mine = envelope.senderId == currentUserId;
    final key = await _groupKey(envelope.groupId);
    if (key == null && !mine) return; // no key yet: retry, do not advance.
    if (key != null) {
      final payload = MessagePayload.fromJson(
        await GroupCipher.decryptJson(envelope.ciphertext, key),
      );
      final isMeta = payload.kind == MessageKind.groupMeta;
      // Our own group-meta is reapplied only during catch-up, so a rejoined
      // device restores its own settings and quick tags. Skipping it on the
      // live subscription keeps a returning echo from clobbering fresh edits.
      if (isMeta && (!mine || applyOwnMeta)) {
        await _applyGroupMeta(payload);
      } else if (!mine && !isMeta) {
        await _ingestFromOther(payload, envelope);
      }
    }

    final current = await db.cursorFor(envelope.groupId);
    if (envelope.seq > current) {
      await db.setCursor(envelope.groupId, envelope.seq);
    }
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
    // Let an in-flight drain finish its current write before the caller closes
    // the database, so a detached publish never lands after teardown.
    await _drainDone;
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    await _syncingController.close();
  }
}
