import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/data/local/database.dart';

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

  test("tagUsageFor counts a member's tags and their last use", () async {
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: 'g1',
            name: 'Ward 7',
            createdBy: 'me',
            encKey: 'k',
          ),
        );
    Future<void> send(String id, String sender, String? tag, DateTime at) => db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: id,
            groupId: 'g1',
            senderId: sender,
            kind: 'text',
            createdAt: at,
            tagId: Value(tag),
          ),
        );
    await send('a', 'me', 'parking', DateTime(2026, 1, 10));
    await send('b', 'me', 'parking', DateTime(2026, 1, 12));
    await send('c', 'me', 'pole', DateTime(2026, 1, 11));
    await send('d', 'me', null, DateTime(2026, 1, 13));
    await send('e', 'other', 'pole', DateTime(2026, 1, 14));

    final usage = await db.tagUsageFor('g1', 'me');
    expect(usage.keys.toSet(), {'parking', 'pole'});
    expect(usage['parking']!.count, 2);
    expect(usage['parking']!.lastUsed, DateTime(2026, 1, 12));
    expect(usage['pole']!.count, 1);
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
