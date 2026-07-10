import 'dart:typed_data';

/// Stores encrypted media blobs by id. Backed by an in-memory map in tests
/// and by Supabase Storage in production. Only ciphertext is ever stored.
abstract interface class BlobStore {
  Future<void> put(String id, Uint8List ciphertext);
  Future<Uint8List?> get(String id);

  /// Deletes a blob, so media removed with a message or a purged group does not
  /// linger on the server. A missing blob is not an error.
  Future<void> remove(String id);
}

/// In-memory blob store for tests and local development.
class InMemoryBlobStore implements BlobStore {
  final Map<String, Uint8List> _blobs = {};

  @override
  Future<void> put(String id, Uint8List ciphertext) async {
    _blobs[id] = ciphertext;
  }

  @override
  Future<Uint8List?> get(String id) async => _blobs[id];

  @override
  Future<void> remove(String id) async {
    _blobs.remove(id);
  }
}
