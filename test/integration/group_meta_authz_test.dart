import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/features/sync/blob_store.dart';
import 'package:hulaki/features/sync/in_memory_transport.dart';

import 'admin_handshake_test.dart';

/// Group metadata (name, description, area, settings) may be changed only by a
/// verified admin. A signed edit from a non-admin member is dropped on every
/// other device, so a member cannot rename or repurpose a group they joined.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a non-admin member cannot rename the group', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final creator = Device('creator', transport, blobs);
    final member = Device('member', transport, blobs);
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
      () async => (await member.db.groupById(group.id))?.name == 'Riverside',
    );

    // The member (not an admin) tries to rename, then sends a normal message.
    await member.groups.renameGroup(group.id, 'HIJACKED');
    final marker = await member.sync.sendText(
      groupId: group.id,
      text: 'ordinary message',
    );

    // Once the later message lands on the creator, the earlier rename envelope
    // has already been processed, so a still-original name proves it was
    // dropped rather than merely in flight.
    await waitFor(() async {
      final messages = await creator.db.messagesFor(group.id);
      return messages.any((m) => m.id == marker);
    });
    expect((await creator.db.groupById(group.id))?.name, 'Riverside');
  });

  test('the creator can rename, and a promoted member can too', () async {
    final transport = InMemoryTransport();
    final blobs = InMemoryBlobStore();
    final creator = Device('creator', transport, blobs);
    final member = Device('member', transport, blobs);
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
      () async => (await member.db.groupById(group.id))?.name == 'Riverside',
    );

    // An admin (the creator) rename converges on the member.
    await creator.groups.renameGroup(group.id, 'Riverside East');
    await waitFor(
      () async =>
          (await member.db.groupById(group.id))?.name == 'Riverside East',
    );

    // Promote the member through the real handshake.
    await waitFor(
      () async => (await creator.db.profileById('member'))?.signingKey != null,
    );
    await creator.groups.inviteAdmin(group.id, 'member', creator.identity);
    await waitFor(() async {
      final rows = await member.db.adminEventsFor(group.id);
      return rows.any((e) => e.kind == 'invite' && e.subjectId == 'member');
    });
    await member.groups.acceptAdmin(group.id, member.identity);
    await waitFor(
      () async => (await member.admins(group.id)).contains('member'),
    );
    await waitFor(
      () async => (await creator.admins(group.id)).contains('member'),
    );

    // Now the member's rename is accepted on the creator's device.
    await member.groups.renameGroup(group.id, 'Member Renamed');
    await waitFor(
      () async =>
          (await creator.db.groupById(group.id))?.name == 'Member Renamed',
    );
  });
}
