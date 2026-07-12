import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/features/identity/guard_request.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';

/// The signing strings must match the literals the group-guard Edge Function
/// verifies (supabase/functions/group-guard/index.ts). If either side changes,
/// these break, so a request cannot silently start failing verification.
void main() {
  test('signing strings match the guard contract', () {
    expect(
      GuardRequest.purgeGroupMessage('g1', 1720000000),
      'purge-group|g1|1720000000',
    );
    expect(
      GuardRequest.deleteListingMessage('g1', 1720000000),
      'delete-listing|g1|1720000000',
    );
    expect(
      GuardRequest.editListingMessage('g1', 1720000000, '{"a":1}'),
      'edit-listing|g1|1720000000|{"a":1}',
    );
  });

  test('a request body signs its message and carries the public key', () async {
    final identity = await IdentityKeys.generate();
    final body = await GuardRequest.purgeGroup(
      identity: identity,
      groupId: 'g1',
      ts: 1720000000,
    );

    expect(body['action'], 'purge-group');
    expect(body['group_id'], 'g1');
    expect(body['ts'], 1720000000);
    expect(body['requester_pubkey'], base64Encode(identity.signingPublic));

    final verified = await IdentityKeys.verify(
      utf8.encode(GuardRequest.purgeGroupMessage('g1', 1720000000)),
      signature: base64Decode(body['sig'] as String),
      signerPublic: identity.signingPublic,
    );
    expect(verified, isTrue);
  });

  test('edit-listing carries the exact signed listing string', () async {
    final identity = await IdentityKeys.generate();
    const listing = '{"group_id":"g1","name":"Riverside"}';
    final body = await GuardRequest.editListing(
      identity: identity,
      groupId: 'g1',
      ts: 1720000000,
      listing: listing,
    );

    expect(body['listing'], listing);
    final verified = await IdentityKeys.verify(
      utf8.encode(GuardRequest.editListingMessage('g1', 1720000000, listing)),
      signature: base64Decode(body['sig'] as String),
      signerPublic: identity.signingPublic,
    );
    expect(verified, isTrue);
  });
}
