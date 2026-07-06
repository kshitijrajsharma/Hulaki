import 'dart:typed_data';

import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production media store. Encrypted blobs live in a Storage bucket by id.
class SupabaseBlobStore implements BlobStore {
  SupabaseBlobStore(this._client, {this.bucket = 'media'});

  final SupabaseClient _client;
  final String bucket;

  @override
  Future<void> put(String id, Uint8List ciphertext) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          id,
          ciphertext,
          fileOptions: const FileOptions(upsert: true),
        );
  }

  @override
  Future<Uint8List?> get(String id) async {
    try {
      return await _client.storage.from(bucket).download(id);
    } on StorageException catch (error) {
      // A missing object is reported as a 400 whose body carries a 404
      // not-found; treat that as absent rather than an error.
      if (error.statusCode == '404' ||
          error.message.contains('not_found') ||
          error.message.contains('not found')) {
        return null;
      }
      rethrow;
    }
  }
}
