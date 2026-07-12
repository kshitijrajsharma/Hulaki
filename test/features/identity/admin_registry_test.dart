import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/features/identity/admin_registry.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';

/// The registry enforces the rule that lets a server authorise deletes without
/// a group key: a group is seeded by one self-signed root, and every later
/// admin must be authorised by a key that is already an admin.
void main() {
  late IdentityKeys creator;
  late IdentityKeys member;
  late IdentityKeys stranger;

  setUp(() async {
    creator = await IdentityKeys.generate();
    member = await IdentityKeys.generate();
    stranger = await IdentityKeys.generate();
  });

  Future<AdminStatement> grant(
    IdentityKeys signer,
    IdentityKeys subject, {
    String groupId = 'g1',
  }) =>
      signAdminStatement(
        signer: signer,
        groupId: groupId,
        adminPublic: subject.signingPublic,
      );

  test('a self-signed root seeds the group', () async {
    final registry = InMemoryAdminRegistry();
    await registry.submit(await grant(creator, creator));
    expect(
      await registry.adminsFor('g1'),
      {_b64(creator)},
    );
  });

  test('an existing admin can add another admin', () async {
    final registry = InMemoryAdminRegistry();
    await registry.submit(await grant(creator, creator));
    await registry.submit(await grant(creator, member));
    expect(
      await registry.adminsFor('g1'),
      {_b64(creator), _b64(member)},
    );
  });

  test('a group cannot be seeded by a non-root statement', () async {
    final registry = InMemoryAdminRegistry();
    // The creator tries to grant the member without seeding a root first.
    final premature = await grant(creator, member);
    await expectLater(
      registry.submit(premature),
      throwsA(isA<AdminRegistryException>()),
    );
    expect(await registry.adminsFor('g1'), isEmpty);
  });

  test('a non-admin cannot add an admin', () async {
    final registry = InMemoryAdminRegistry();
    await registry.submit(await grant(creator, creator));
    // The stranger, who is not an admin, tries to enrol itself.
    final selfEnrol = await grant(stranger, stranger);
    await expectLater(
      registry.submit(selfEnrol),
      throwsA(isA<AdminRegistryException>()),
    );
    expect(await registry.adminsFor('g1'), {_b64(creator)});
  });

  test('a second root cannot take over an established group', () async {
    final registry = InMemoryAdminRegistry();
    await registry.submit(await grant(creator, creator));
    // A stranger self-signs a root for the same group id.
    final takeover = await grant(stranger, stranger);
    await expectLater(
      registry.submit(takeover),
      throwsA(isA<AdminRegistryException>()),
    );
    expect(await registry.adminsFor('g1'), {_b64(creator)});
  });

  test('a forged signature is rejected', () async {
    final registry = InMemoryAdminRegistry();
    await registry.submit(await grant(creator, creator));
    final real = await grant(creator, member);
    // Claim the creator authorised it, but sign nothing valid.
    final forged = AdminStatement(
      groupId: real.groupId,
      adminPubkey: real.adminPubkey,
      addedBy: real.addedBy,
      sig: (await grant(stranger, member)).sig,
    );
    await expectLater(
      registry.submit(forged),
      throwsA(isA<AdminRegistryException>()),
    );
    expect(await registry.adminsFor('g1'), {_b64(creator)});
  });

  test('a statement is bound to its group id', () async {
    final registry = InMemoryAdminRegistry();
    await registry.submit(await grant(creator, creator));
    await registry.submit(await grant(creator, creator, groupId: 'g2'));
    // A g2 root does not make anyone an admin of g1.
    await registry.submit(await grant(creator, member, groupId: 'g2'));
    expect(await registry.adminsFor('g1'), {_b64(creator)});
    expect(
      await registry.adminsFor('g2'),
      {_b64(creator), _b64(member)},
    );
  });
}

String _b64(IdentityKeys keys) => base64Encode(keys.signingPublic);
