import 'package:hulaki/features/recovery/backup_crypto.dart';
import 'package:hulaki/features/recovery/backup_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The production backup store. Reads and writes go through the group-guard
/// function, which alone holds table access, so no client can enumerate or
/// bulk-delete backups. The server still only ever sees ciphertext.
class SupabaseBackupStore implements BackupStore {
  SupabaseBackupStore(this._client);

  final SupabaseClient _client;
  static const _guard = 'group-guard';

  @override
  Future<void> put(EncryptedBackup backup) async {
    try {
      await _client.functions.invoke(
        _guard,
        body: {
          'action': 'backup-put',
          'lookup_id': backup.lookupId,
          'ciphertext': backup.ciphertext,
          'key_wrapped_key': backup.keyWrappedKey,
        },
      );
    } on FunctionException catch (error) {
      throw BackupStoreException('backup upload failed (${error.status})');
    }
  }

  @override
  Future<EncryptedBackup?> getByLookupId(String lookupId) async {
    try {
      final response = await _client.functions.invoke(
        _guard,
        body: {'action': 'backup-get', 'lookup_id': lookupId},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['found'] != true) return null;
      return EncryptedBackup(
        lookupId: data['lookup_id'] as String,
        ciphertext: data['ciphertext'] as String,
        keyWrappedKey: data['key_wrapped_key'] as String,
      );
    } on FunctionException catch (error) {
      throw BackupStoreException('backup fetch failed (${error.status})');
    }
  }
}
