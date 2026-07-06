import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDatabase db;

  setUp(() => db = LocalDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('upserts and reads back a profile', () async {
    await db.upsertProfile(
      ProfilesCompanion.insert(id: 'local-1', phone: '+9779812345678'),
    );

    final profile = await db.profileById('local-1');
    expect(profile, isNotNull);
    expect(profile!.phone, '+9779812345678');
  });

  test('a fresh database has no active groups', () async {
    expect(await db.activeGroups(), isEmpty);
  });

  test('a message round-trips altitude and heading', () async {
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: 'g1',
            name: 'Ward 7',
            createdBy: 'local-1',
            encKey: 'k',
          ),
        );
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: 'm1',
            groupId: 'g1',
            senderId: 'local-1',
            kind: 'text',
            createdAt: DateTime(2026),
            altitudeM: const Value(1320),
            headingDeg: const Value(47),
          ),
        );

    final message = await db.latestMessage('g1');
    expect(message!.altitudeM, 1320);
    expect(message.headingDeg, 47);
  });

  test('watchMembersFor lists admins first with profile names', () async {
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: 'g1',
            name: 'Ward 7',
            createdBy: 'admin-1',
            encKey: 'k',
          ),
        );
    await db.upsertProfile(
      ProfilesCompanion.insert(id: 'admin-1', phone: '+1'),
    );
    await db.upsertProfile(
      ProfilesCompanion.insert(
        id: 'member-1',
        phone: '+2',
        displayName: const Value('Sita'),
      ),
    );
    await db
        .into(db.groupMembers)
        .insert(
          GroupMembersCompanion.insert(
            groupId: 'g1',
            profileId: 'member-1',
            joinedAt: Value(DateTime(2026, 1, 2)),
          ),
        );
    await db
        .into(db.groupMembers)
        .insert(
          GroupMembersCompanion.insert(
            groupId: 'g1',
            profileId: 'admin-1',
            role: const Value('admin'),
            joinedAt: Value(DateTime(2026, 1, 3)),
          ),
        );

    final members = await db.watchMembersFor('g1').first;
    expect(members.map((m) => m.profileId), ['admin-1', 'member-1']);
    expect(members.first.isAdmin, isTrue);
    expect(members[1].name, 'Sita');
  });
}
