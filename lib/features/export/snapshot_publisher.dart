import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/export/shared_snapshot.dart';
import 'package:hulaki/features/export/snapshot_store.dart';
import 'package:hulaki/features/sync/group_cipher.dart';
import 'package:uuid/uuid.dart';

/// Where the web viewer is hosted. The snapshot id rides the query; the
/// per-link key rides the fragment, which the browser never sends to a server.
const _viewerBase = 'https://kshitijrajsharma.github.io/Hulaki/view.html';

/// How many photo objects to upload at once, to keep a large publish from
/// opening a thousand connections while still finishing promptly.
const _uploadConcurrency = 5;

/// Publishes a group's data as an encrypted web snapshot and revokes it later.
/// The points live in one small JSON object and each photo in its own object,
/// all encrypted with a fresh key that is not the group key. The server holds
/// only ciphertext and no author identity is ever included.
class SnapshotPublisher {
  SnapshotPublisher(this._db, this._store);

  final LocalDatabase _db;
  final SnapshotStore _store;

  /// Builds, encrypts, and uploads a snapshot and records it locally. Returns
  /// the shareable link, with the key in its fragment.
  Future<String> publish(Group group, {required DateTime now}) async {
    final key = await GroupCipher.generateKey();
    final id = const Uuid().v4();
    await _buildAndUpload(group, id, key, now);

    final url = '$_viewerBase?s=$id#${_fragmentKey(key)}';
    await _db
        .into(_db.webSnapshots)
        .insert(
          WebSnapshotsCompanion.insert(
            id: id,
            groupId: group.id,
            url: url,
            createdAt: now,
          ),
        );
    return url;
  }

  /// Refreshes an existing link in place: rebuilds the group's current data,
  /// re-encrypts it with the link's own key, and overwrites the stored objects
  /// so the same URL serves the latest snapshot.
  Future<void> update(WebSnapshot snapshot, {required DateTime now}) async {
    final group = await _db.groupById(snapshot.groupId);
    if (group == null) return;
    await _buildAndUpload(group, snapshot.id, _keyFromUrl(snapshot.url), now);
    await (_db.update(
      _db.webSnapshots,
    )..where((s) => s.id.equals(snapshot.id))).write(
      WebSnapshotsCompanion(updatedAt: Value(now)),
    );
  }

  /// Rebuilds the group's snapshot and uploads it under [id], encrypted with
  /// [key]. Overwrites any existing objects at those paths.
  Future<void> _buildAndUpload(
    Group group,
    String id,
    Uint8List key,
    DateTime now,
  ) async {
    final messages = await _db.messagesFor(group.id);
    final hotKeys = await _db.hotKeysFor(group.id);

    final mediaBytes = <String, Uint8List>{};
    for (final message in messages) {
      final mediaId = message.mediaId;
      if (mediaId != null && !mediaBytes.containsKey(mediaId)) {
        final bytes = await _db.mediaBytes(mediaId);
        if (bytes != null) mediaBytes[mediaId] = bytes;
      }
    }

    final snapshot = await buildSharedSnapshot(
      groupName: group.name,
      messages: messages,
      hotKeys: hotKeys,
      mediaBytes: mediaBytes,
      generatedAt: now,
    );

    await _store.put(
      '$id/data',
      await GroupCipher.encryptBytes(snapshotToBytes(snapshot.data), key),
    );
    await _uploadPhotos(id, snapshot.photos, key);
  }

  /// Recovers a link's encryption key from the base64url in its URL fragment.
  Uint8List _keyFromUrl(String url) {
    final fragment = Uri.parse(url).fragment;
    final padded = fragment.padRight(
      fragment.length + (4 - fragment.length % 4) % 4,
      '=',
    );
    return base64Url.decode(padded);
  }

  Future<void> _uploadPhotos(
    String id,
    Map<String, Uint8List> photos,
    Uint8List key,
  ) async {
    final entries = photos.entries.toList();
    for (var i = 0; i < entries.length; i += _uploadConcurrency) {
      final batch = entries.skip(i).take(_uploadConcurrency);
      await Future.wait([
        for (final entry in batch)
          GroupCipher.encryptBytes(entry.value, key).then(
            (cipher) => _store.put('$id/${entry.key}', cipher),
          ),
      ]);
    }
  }

  /// Deletes the snapshot and its photos, and its local record, so the link
  /// stops resolving.
  Future<void> revoke(String id) async {
    await _store.removeSnapshot(id);
    await (_db.delete(_db.webSnapshots)..where((s) => s.id.equals(id))).go();
  }

  Future<List<WebSnapshot>> snapshotsFor(String groupId) =>
      (_db.select(_db.webSnapshots)
            ..where((s) => s.groupId.equals(groupId))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .get();

  /// Live list of a group's published snapshots, so the manage sheet updates as
  /// links are added or revoked.
  Stream<List<WebSnapshot>> watchSnapshotsFor(String groupId) =>
      (_db.select(_db.webSnapshots)
            ..where((s) => s.groupId.equals(groupId))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .watch();
}

/// URL-safe, unpadded base64 of the raw key, for the link fragment.
String _fragmentKey(Uint8List key) => base64Url.encode(key).replaceAll('=', '');
