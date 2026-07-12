import 'package:hulaki/features/identity/admin_registry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The production admin registry. Reads are direct (public keys only); writes
/// go through the group-guard Edge Function, which verifies the signature
/// chain and writes with the service role, so a member cannot enrol itself.
class SupabaseAdminRegistry implements AdminRegistry {
  SupabaseAdminRegistry(this._client);

  final SupabaseClient _client;
  static const _table = 'group_admins';
  static const _function = 'group-guard';

  @override
  Future<void> submit(AdminStatement statement) async {
    final response = await _client.functions.invoke(
      _function,
      body: {'action': 'add-admin', 'statement': statement.toJson()},
    );
    if (response.status != 200) {
      throw AdminRegistryException(
        'add-admin rejected (${response.status}): ${response.data}',
      );
    }
  }

  @override
  Future<Set<String>> adminsFor(String groupId) async {
    final rows = await _client
        .from(_table)
        .select('admin_pubkey')
        .eq('group_id', groupId);
    return {for (final row in rows) row['admin_pubkey'] as String};
  }
}
