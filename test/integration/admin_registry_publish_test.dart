import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/features/identity/admin_registry.dart';
import 'package:hulaki/features/sync/blob_store.dart';
import 'package:hulaki/features/sync/in_memory_transport.dart';

import 'admin_handshake_test.dart';

/// Creating a group and promoting a member publish the server-readable admin
/// set, so the guard can later authorise their deletes. Devices share one
/// registry, standing in for the Edge Function that enforces the same rules.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('createGroup publishes the creator as the root admin', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final registry = InMemoryAdminRegistry();
    final creator = Device(
      'creator',
      transport,
      blobs,
      adminRegistry: registry,
    );
    await creator.init();
    addTearDown(() async {
      await creator.dispose();
      await transport.dispose();
    });

    final group = await creator.groups.createGroup(
      name: 'Riverside',
      identity: creator.identity,
      hotKeys: const [],
    );

    expect(
      await registry.adminsFor(group.id),
      {base64Encode(creator.identity.signingPublic)},
    );
  });

  test('inviting a member enrols them in the registry', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final registry = InMemoryAdminRegistry();
    final creator = Device(
      'creator',
      transport,
      blobs,
      adminRegistry: registry,
    );
    final member = Device('member', transport, blobs, adminRegistry: registry);
    await creator.init();
    await member.init();
    addTearDown(() async {
      await creator.dispose();
      await member.dispose();
      await transport.dispose();
    });

    final group = await creator.groups.createGroup(
      name: 'Riverside',
      identity: creator.identity,
      hotKeys: const [],
    );
    final link = creator.groups.inviteLinkFor(group);
    await member.groups.joinViaLink(link, member.identity);
    await waitFor(
      () async => (await creator.db.profileById('member'))?.signingKey != null,
    );

    await creator.groups.inviteAdmin(group.id, 'member', creator.identity);

    expect(
      await registry.adminsFor(group.id),
      {
        base64Encode(creator.identity.signingPublic),
        base64Encode(member.identity.signingPublic),
      },
    );
  });

  test('a member cannot enrol itself once the creator root exists', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final registry = InMemoryAdminRegistry();
    final creator = Device(
      'creator',
      transport,
      blobs,
      adminRegistry: registry,
    );
    final member = Device('member', transport, blobs, adminRegistry: registry);
    await creator.init();
    await member.init();
    addTearDown(() async {
      await creator.dispose();
      await member.dispose();
      await transport.dispose();
    });

    final group = await creator.groups.createGroup(
      name: 'Riverside',
      identity: creator.identity,
      hotKeys: const [],
    );
    final link = creator.groups.inviteLinkFor(group);
    await member.groups.joinViaLink(link, member.identity);
    await waitFor(
      () async => (await member.db.groupById(group.id))?.adminRootKey != null,
    );

    // The member, not an admin, self-signs to enrol itself. The group already
    // has the creator's root, so the registry rejects the take-over attempt.
    final selfStatement = await signAdminStatement(
      signer: member.identity,
      groupId: group.id,
      adminPublic: member.identity.signingPublic,
    );
    await expectLater(
      registry.submit(selfStatement),
      throwsA(isA<AdminRegistryException>()),
    );
    expect(
      await registry.adminsFor(group.id),
      {base64Encode(creator.identity.signingPublic)},
    );
  });
}
