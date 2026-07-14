import 'dart:typed_data';

import 'package:hulaki/features/export/snapshot_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production snapshot store. Encrypted objects live in a public Storage bucket
/// under `<id>/…`; each object is ciphertext, so public read is safe.
class SupabaseSnapshotStore implements SnapshotStore {
  SupabaseSnapshotStore(this._client, {this.bucket = 'snapshots'});

  final SupabaseClient _client;
  final String bucket;

  @override
  Future<void> put(String path, Uint8List ciphertext) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          ciphertext,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/octet-stream',
          ),
        );
  }

  @override
  Future<void> removeSnapshot(String id) async {
    final items = await _client.storage.from(bucket).list(path: id);
    final paths = [for (final item in items) '$id/${item.name}'];
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove(paths);
    } on StorageException catch (error) {
      if (error.statusCode == '404' ||
          error.message.contains('not_found') ||
          error.message.contains('not found')) {
        return;
      }
      rethrow;
    }
  }
}
