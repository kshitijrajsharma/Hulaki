import 'dart:typed_data';

/// Stores encrypted web snapshot objects by path. A snapshot is a small JSON at
/// `<id>/data` plus one object per photo at `<id>/<pointId>`. Only ciphertext is
/// ever stored; the per-link key stays in the shared URL fragment. Backed by an
/// in-memory map in tests and by Supabase Storage in production.
abstract interface class SnapshotStore {
  /// Uploads ciphertext at [path] (which may contain a `/`).
  Future<void> put(String path, Uint8List ciphertext);

  /// Deletes every object under `<id>/`, so a revoked snapshot and all its
  /// photos stop resolving. Missing objects are not an error.
  Future<void> removeSnapshot(String id);
}

/// In-memory snapshot store for tests and keyless local runs.
class InMemorySnapshotStore implements SnapshotStore {
  final Map<String, Uint8List> _objects = {};

  @override
  Future<void> put(String path, Uint8List ciphertext) async {
    _objects[path] = ciphertext;
  }

  @override
  Future<void> removeSnapshot(String id) async {
    _objects.removeWhere((path, _) => path == id || path.startsWith('$id/'));
  }

  Uint8List? read(String path) => _objects[path];

  int get count => _objects.length;
}
