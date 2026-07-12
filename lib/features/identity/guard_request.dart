import 'dart:convert';

import 'package:hulaki/features/identity/identity_crypto.dart';

/// Builds the signed request bodies the group-guard Edge Function expects. The
/// signing strings here must match the ones the function verifies, so they are
/// defined once and covered by a contract test. Each carries a fresh timestamp
/// the server checks against a short window to bound replay.
class GuardRequest {
  const GuardRequest._();

  static String purgeGroupMessage(String groupId, int ts) =>
      'purge-group|$groupId|$ts';

  static String deleteListingMessage(String groupId, int ts) =>
      'delete-listing|$groupId|$ts';

  static String editListingMessage(String groupId, int ts, String listing) =>
      'edit-listing|$groupId|$ts|$listing';

  static Future<Map<String, dynamic>> purgeGroup({
    required IdentityKeys identity,
    required String groupId,
    required int ts,
  }) async =>
      _signed(
        action: 'purge-group',
        groupId: groupId,
        ts: ts,
        message: purgeGroupMessage(groupId, ts),
        identity: identity,
      );

  static Future<Map<String, dynamic>> deleteListing({
    required IdentityKeys identity,
    required String groupId,
    required int ts,
  }) async =>
      _signed(
        action: 'delete-listing',
        groupId: groupId,
        ts: ts,
        message: deleteListingMessage(groupId, ts),
        identity: identity,
      );

  static Future<Map<String, dynamic>> editListing({
    required IdentityKeys identity,
    required String groupId,
    required int ts,
    required String listing,
  }) async {
    final body = await _signed(
      action: 'edit-listing',
      groupId: groupId,
      ts: ts,
      message: editListingMessage(groupId, ts, listing),
      identity: identity,
    );
    return {...body, 'listing': listing};
  }

  static Future<Map<String, dynamic>> _signed({
    required String action,
    required String groupId,
    required int ts,
    required String message,
    required IdentityKeys identity,
  }) async => {
    'action': action,
    'group_id': groupId,
    'requester_pubkey': base64Encode(identity.signingPublic),
    'ts': ts,
    'sig': base64Encode(await identity.sign(utf8.encode(message))),
  };
}
