import 'package:hulaki/features/recovery/backup_crypto.dart';

/// Stores the encrypted recovery backup. The server only ever holds ciphertext,
/// so this interface never sees the recovery bundle in the clear.
abstract interface class BackupStore {
  Future<void> put(EncryptedBackup backup);

  Future<EncryptedBackup?> getByLookupId(String lookupId);
}

/// Raised when the backup store cannot reach or use the server.
class BackupStoreException implements Exception {
  const BackupStoreException(this.message);

  final String message;

  @override
  String toString() => 'BackupStoreException: $message';
}

/// In-memory store for tests and keyless local runs.
class InMemoryBackupStore implements BackupStore {
  final _byLookup = <String, EncryptedBackup>{};

  @override
  Future<void> put(EncryptedBackup backup) async =>
      _byLookup[backup.lookupId] = backup;

  @override
  Future<EncryptedBackup?> getByLookupId(String lookupId) async =>
      _byLookup[lookupId];
}
