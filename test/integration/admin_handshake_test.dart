import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/admin_chain.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// One simulated device: its store, sync engine, group service and identity.
class Device {
  Device(this.userId, InMemoryTransport transport, InMemoryBlobStore blobs)
    : db = LocalDatabase(NativeDatabase.memory()) {
    sync = SyncService(
      db: db,
      transport: transport,
      blobStore: blobs,
      currentUserId: userId,
      identity: () async => identity,
    );
    groups = GroupService(db: db, sync: sync, currentUserId: userId);
  }

  final String userId;
  final LocalDatabase db;
  late final SyncService sync;
  late final GroupService groups;
  late final IdentityKeys identity;

  Future<void> init() async {
    identity = await IdentityKeys.generate();
    await db.upsertProfile(
      ProfilesCompanion.insert(id: userId, phone: ''),
    );
  }

  /// Whether a handshake event of [kind] has arrived for the group. A light
  /// read, so polling it does not starve the ingest pipeline.
  Future<bool> hasEvent(String groupId, String kind) async {
    final rows = await db.adminEventsFor(groupId);
    return rows.any((e) => e.kind == kind);
  }

  /// The verified admin set on this device, derived read-only from the stored
  /// signed events so polling it does not contend with the ingest pipeline.
  Future<Set<String>> admins(String groupId) async {
    final group = await db.groupById(groupId);
    final rootKey = group?.adminRootKey;
    if (group == null || rootKey == null || group.createdBy.isEmpty) {
      return {if (group?.createdBy.isNotEmpty ?? false) group!.createdBy};
    }
    final rows = await db.adminEventsFor(groupId);
    final events = [
      for (final row in rows)
        AdminEvent(
          kind: row.kind,
          groupId: row.groupId,
          actorId: row.actorId,
          actorPublic: base64Decode(row.actorPublic),
          subjectId: row.subjectId,
          subjectPublic: row.subjectPublic == null
              ? null
              : base64Decode(row.subjectPublic!),
          signature: base64Decode(row.signature),
        ),
    ];
    return verifiedAdmins(
      creatorId: group.createdBy,
      creatorPublic: base64Decode(rootKey),
      events: events,
    );
  }

  Future<void> dispose() async {
    await sync.dispose();
    await db.close();
  }
}

Future<void> waitFor(
  Future<bool> Function() condition, {
  int tries = 600,
}) async {
  for (var i = 0; i < tries; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition was not met in time');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a member becomes admin only after inviting and accepting', () async {
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

    // The creator learns the member's identity from their join announce.
    await waitFor(
      () async => (await creator.db.profileById('member'))?.signingKey != null,
    );

    // The creator invites the member. An invite alone does not promote.
    await creator.groups.inviteAdmin(group.id, 'member', creator.identity);
    await waitFor(() async {
      final rows = await member.db.adminEventsFor(group.id);
      return rows.any((e) => e.kind == 'invite' && e.subjectId == 'member');
    });
    expect((await member.admins(group.id)).contains('member'), isFalse);
    expect((await creator.admins(group.id)).contains('member'), isFalse);

    // The member accepts, and both devices converge on the member as admin.
    await member.groups.acceptAdmin(group.id, member.identity);
    await waitFor(() => creator.hasEvent(group.id, 'accept'));
    await waitFor(() => member.hasEvent(group.id, 'accept'));
    expect((await creator.admins(group.id)).contains('member'), isTrue);
    expect((await member.admins(group.id)).contains('member'), isTrue);
    // The creator stays admin throughout.
    expect((await creator.admins(group.id)).contains('creator'), isTrue);
  });

  test('an accept without an invite does not grant admin', () async {
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
      () async => (await member.db.groupById(group.id))?.adminRootKey != null,
    );

    // The member self-accepts with no invite; it must be rejected everywhere.
    await member.groups.acceptAdmin(group.id, member.identity);
    await waitFor(() async {
      final rows = await creator.db.adminEventsFor(group.id);
      return rows.any((e) => e.kind == 'accept');
    });

    expect((await member.admins(group.id)).contains('member'), isFalse);
    expect((await creator.admins(group.id)).contains('member'), isFalse);
  });
}
