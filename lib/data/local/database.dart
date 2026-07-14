import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:hulaki/features/groups/group_member_view.dart';

part 'database.g.dart';

/// People known to this device: the signed-in user and any group members.
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get phone => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get signingKey => text().nullable()();
  TextColumn get agreementKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A mapping group. The conversation and the shared map are two views of it.
///
/// [encKey] is the base64 group encryption key (shared out of band via the
/// invite link, never sent to the server). [aoiGeoJson] is the optional
/// mapping area drawn or imported on creation.
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get createdBy => text()();
  TextColumn get encKey => text()();
  TextColumn get aoiGeoJson => text().nullable()();
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();
  BoolColumn get joinApproval => boolean().withDefault(const Constant(false))();
  TextColumn get adminRootKey => text().nullable()();

  /// Directory reach when public: 'local' lists the group by proximity to its
  /// mapped area, 'global' lists it in the worldwide feed with no location.
  TextColumn get scope => text().withDefault(const Constant('local'))();

  /// True for the seeded tutorial sample, so the thread can offer to remove it.
  BoolColumn get isSample => boolean().withDefault(const Constant(false))();

  /// Moderation controls, all set by an admin and shared through group-meta.
  /// [allowMemberExport] lets non-admins export; [allowMemberPlace] lets them
  /// place points by tapping the map rather than only sending their live fix;
  /// [allowOutsideArea] permits points beyond the mapping area; [gpsLimitM]
  /// caps the accuracy a sent fix may carry, in metres, null meaning no cap;
  /// [allowMemberTags] lets non-admins add, edit and remove the quick tags.
  BoolColumn get allowMemberExport =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get allowMemberPlace =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get allowOutsideArea =>
      boolean().withDefault(const Constant(true))();
  IntColumn get gpsLimitM => integer().nullable()();
  BoolColumn get allowMemberTags =>
      boolean().withDefault(const Constant(false))();

  BlobColumn get photo => blob().nullable()();

  /// The cover photo shared with members: its encrypted blob id in object
  /// storage and the base64 key to decrypt it. Both null when there is no
  /// synced photo. The bytes themselves live in [photo] once fetched.
  TextColumn get photoBlobId => text().nullable()();
  TextColumn get photoKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A tap-able tag inside a group: a label plus the colour it carries on the
/// map. Position orders them in the composer bar.
@TableIndex(name: 'hot_keys_group', columns: {#groupId})
class HotKeys extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get label => text()();
  IntColumn get colorValue => integer()();
  TextColumn get iconName => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Membership of a profile in a group, with its role.
class GroupMembers extends Table {
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get role => text().withDefault(const Constant('member'))();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {groupId, profileId};
}

/// Every message is a field observation. Media is referenced by id; the bytes
/// live in [MediaBlobs] locally and as ciphertext in object storage.
@TableIndex(name: 'messages_group_created', columns: {#groupId, #createdAt})
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get senderId => text()();
  TextColumn get kind => text()();
  TextColumn get body => text().nullable()();
  TextColumn get tagId => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  RealColumn get accuracyM => real().nullable()();
  RealColumn get altitudeM => real().nullable()();
  RealColumn get headingDeg => real().nullable()();
  BoolColumn get locationPending =>
      boolean().withDefault(const Constant(false))();
  TextColumn get mediaId => text().nullable()();
  TextColumn get mediaMime => text().nullable()();
  TextColumn get mediaKey => text().nullable()();
  TextColumn get replyToId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get editedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get sendState => text().withDefault(const Constant('pending'))();
  IntColumn get remoteSeq => integer().nullable()();
  BoolColumn get anonymous => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local plaintext cache of media bytes, keyed by media id.
class MediaBlobs extends Table {
  TextColumn get id => text()();
  BlobColumn get bytes => blob()();
  TextColumn get mime => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The user's breadcrumb trail, drawn as a faint line and purged after 24h.
@TableIndex(name: 'track_owner_time', columns: {#ownerId, #recordedAt})
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerId => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get accuracyM => real()();
  DateTimeColumn get recordedAt => dateTime()();
}

/// Outgoing changes waiting to publish. Every create, edit and delete appends
/// the full plaintext payload here; the drain encrypts and sends it, then the
/// row is removed. This is what survives going offline.
class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get messageId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The signed promotion handshake, kept out of the chat stream. Each row is one
/// [kind] ('invite' or 'accept') so the verified admin set can be recomputed
/// from the creator root whenever a new event arrives.
@DataClassName('AdminEventRow')
class AdminEvents extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  IntColumn get seq => integer().nullable()();
  TextColumn get kind => text()();
  TextColumn get actorId => text()();
  TextColumn get actorPublic => text()();
  TextColumn get subjectId => text()();
  TextColumn get subjectPublic => text().nullable()();
  TextColumn get signature => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-group sync cursor: the highest server sequence pulled so far.
class SyncCursors extends Table {
  TextColumn get groupId => text()();
  IntColumn get lastSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

/// A published web snapshot, tracked locally so its author can re-share or
/// revoke it later. The url holds the per-link key, so it never leaves the
/// device; only the encrypted snapshot itself reaches the server.
class WebSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get url => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The on-device store. It is the source of truth: chat and map render from
/// here, and the network only syncs into and out of it.
@DriftDatabase(
  tables: [
    Profiles,
    Groups,
    HotKeys,
    GroupMembers,
    Messages,
    MediaBlobs,
    TrackPoints,
    Outbox,
    SyncCursors,
    AdminEvents,
    WebSnapshots,
  ],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'hulaki'));

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(groups, groups.photo);
        await m.addColumn(hotKeys, hotKeys.iconName);
      }
      if (from < 3) {
        await m.addColumn(messages, messages.altitudeM);
        await m.addColumn(messages, messages.headingDeg);
      }
      if (from < 4) {
        await m.addColumn(groups, groups.description);
        await m.addColumn(groups, groups.isPublic);
      }
      if (from < 5) {
        await m.create(messagesGroupCreated);
      }
      if (from < 6) {
        await m.addColumn(messages, messages.anonymous);
      }
      if (from < 7) {
        await m.create(hotKeysGroup);
        await m.create(trackOwnerTime);
      }
      if (from < 8) {
        await m.addColumn(profiles, profiles.signingKey);
        await m.addColumn(profiles, profiles.agreementKey);
        await m.addColumn(groups, groups.joinApproval);
        await m.addColumn(groups, groups.adminRootKey);
      }
      if (from < 9) {
        await m.createTable(adminEvents);
      }
      if (from < 10) {
        await m.addColumn(groups, groups.allowMemberExport);
        await m.addColumn(groups, groups.allowMemberPlace);
        await m.addColumn(groups, groups.allowOutsideArea);
        await m.addColumn(groups, groups.gpsLimitM);
      }
      if (from < 11) {
        await m.addColumn(groups, groups.photoBlobId);
        await m.addColumn(groups, groups.photoKey);
      }
      if (from < 12) {
        await m.addColumn(groups, groups.allowMemberTags);
      }
      if (from < 13) {
        await m.addColumn(groups, groups.scope);
      }
      if (from < 14) {
        await m.addColumn(groups, groups.isSample);
      }
      if (from < 15) {
        await m.createTable(webSnapshots);
      }
    },
  );

  Future<void> upsertProfile(ProfilesCompanion profile) =>
      into(profiles).insertOnConflictUpdate(profile);

  Future<Profile?> profileById(String id) =>
      (select(profiles)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Stores a handshake event once, ignoring a replay of the same id.
  Future<void> insertAdminEvent(AdminEventsCompanion event) =>
      into(adminEvents).insert(event, mode: InsertMode.insertOrIgnore);

  /// The group's handshake events in causal order. Ordering by local insertion
  /// time is correct on every device because an invite is always stored before
  /// the accept that answers it, while a locally authored event never carries a
  /// server seq to order against.
  Future<List<AdminEventRow>> adminEventsFor(String groupId) =>
      _adminEventsQuery(groupId).get();

  /// Live handshake events, so a pending admin invite surfaces as it arrives.
  Stream<List<AdminEventRow>> watchAdminEventsFor(String groupId) =>
      _adminEventsQuery(groupId).watch();

  Selectable<AdminEventRow> _adminEventsQuery(String groupId) =>
      select(adminEvents)
        ..where((e) => e.groupId.equals(groupId))
        ..orderBy([
          (e) => OrderingTerm(expression: e.createdAt),
          (e) => OrderingTerm(expression: e.seq),
        ]);

  /// Sets a member's role, inserting the membership if it is new.
  Future<void> setMemberRole(
    String groupId,
    String profileId,
    String role,
  ) async {
    await into(profiles).insert(
      ProfilesCompanion.insert(id: profileId, phone: ''),
      mode: InsertMode.insertOrIgnore,
    );
    await into(groupMembers).insert(
      GroupMembersCompanion.insert(
        groupId: groupId,
        profileId: profileId,
        role: Value(role),
      ),
      onConflict: DoUpdate((_) => GroupMembersCompanion(role: Value(role))),
    );
  }

  Future<Profile?> profileByUsername(String username) => (select(
    profiles,
  )..where((p) => p.displayName.equals(username))).getSingleOrNull();

  Future<List<Profile>> allProfiles() => select(profiles).get();

  Stream<List<Profile>> watchAllProfiles() => select(profiles).watch();

  Future<List<Group>> activeGroups() =>
      (select(groups)..where((g) => g.archivedAt.isNull())).get();

  Stream<List<Group>> watchActiveGroups() =>
      (select(groups)
            ..where((g) => g.archivedAt.isNull())
            ..orderBy([
              (g) => OrderingTerm(
                expression: g.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Stream<List<Group>> watchArchivedGroups() =>
      (select(groups)
            ..where((g) => g.archivedAt.isNotNull())
            ..orderBy([
              (g) => OrderingTerm(
                expression: g.archivedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  /// The most recent visible message in a group, for the chats list preview.
  Future<Message?> latestMessage(String groupId) => _latestMessageQuery(
    groupId,
  ).getSingleOrNull();

  /// Live [latestMessage] so the chats list preview refreshes as messages
  /// arrive, without depending on the group row changing.
  Stream<Message?> watchLatestMessage(String groupId) =>
      _latestMessageQuery(groupId).watchSingleOrNull();

  SimpleSelectStatement<$MessagesTable, Message> _latestMessageQuery(
    String groupId,
  ) => select(messages)
    ..where((m) => m.groupId.equals(groupId) & m.deletedAt.isNull())
    ..orderBy([
      (m) => OrderingTerm(
        expression: m.createdAt,
        mode: OrderingMode.desc,
      ),
    ])
    ..limit(1);

  Future<Group?> groupById(String id) =>
      (select(groups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<List<HotKey>> hotKeysFor(String groupId) =>
      (select(hotKeys)
            ..where((h) => h.groupId.equals(groupId))
            ..orderBy([(h) => OrderingTerm(expression: h.position)]))
          .get();

  Stream<List<HotKey>> watchHotKeysFor(String groupId) =>
      (select(hotKeys)
            ..where((h) => h.groupId.equals(groupId))
            ..orderBy([(h) => OrderingTerm(expression: h.position)]))
          .watch();

  /// The group roster joined with profiles, admins first then by join time.
  Stream<List<GroupMemberView>> watchMembersFor(String groupId) {
    final query =
        select(groupMembers).join([
            leftOuterJoin(
              profiles,
              profiles.id.equalsExp(groupMembers.profileId),
            ),
          ])
          ..where(groupMembers.groupId.equals(groupId))
          ..orderBy([OrderingTerm(expression: groupMembers.joinedAt)]);
    return query.watch().map((rows) {
      final members =
          [
            for (final row in rows)
              GroupMemberView(
                profileId: row.readTable(groupMembers).profileId,
                role: row.readTable(groupMembers).role,
                joinedAt: row.readTable(groupMembers).joinedAt,
                displayName: row.readTableOrNull(profiles)?.displayName,
                phone: row.readTableOrNull(profiles)?.phone,
              ),
          ]..sort((a, b) {
            if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
            return a.joinedAt.compareTo(b.joinedAt);
          });
      return members;
    });
  }

  /// Visible messages for a group, oldest first, deletions excluded.
  Future<List<Message>> messagesFor(String groupId) =>
      (select(messages)
            ..where((m) => m.groupId.equals(groupId) & m.deletedAt.isNull())
            ..orderBy([(m) => OrderingTerm(expression: m.createdAt)]))
          .get();

  Stream<List<Message>> watchMessages(String groupId) =>
      (select(messages)
            ..where((m) => m.groupId.equals(groupId) & m.deletedAt.isNull())
            ..orderBy([(m) => OrderingTerm(expression: m.createdAt)]))
          .watch();

  Future<List<Message>> pendingMessages() =>
      (select(messages)..where((m) => m.sendState.equals('pending'))).get();

  /// Live count of this device's captures not yet uploaded, so the UI can
  /// reassure the user their field data is saved and show upload progress.
  Stream<int> watchPendingCount() {
    final count = messages.id.count();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(
        messages.sendState.equals('pending') & messages.deletedAt.isNull(),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Stream<int> watchPendingCountFor(String groupId) {
    final count = messages.id.count();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(
        messages.groupId.equals(groupId) &
            messages.sendState.equals('pending') &
            messages.deletedAt.isNull(),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<Uint8List?> mediaBytes(String id) async {
    final blob = await (select(
      mediaBlobs,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
    return blob?.bytes;
  }

  Future<void> enqueueOutbox(OutboxData entry) =>
      into(outbox).insertOnConflictUpdate(entry);

  Future<List<OutboxData>> outboxEntries() => (select(
    outbox,
  )..orderBy([(o) => OrderingTerm(expression: o.createdAt)])).get();

  Future<void> deleteOutbox(String id) =>
      (delete(outbox)..where((o) => o.id.equals(id))).go();

  Future<int> cursorFor(String groupId) async {
    final row = await (select(
      syncCursors,
    )..where((c) => c.groupId.equals(groupId))).getSingleOrNull();
    return row?.lastSeq ?? 0;
  }

  Future<void> setCursor(String groupId, int seq) => into(syncCursors).insert(
    SyncCursorsCompanion.insert(groupId: groupId, lastSeq: Value(seq)),
    onConflict: DoUpdate((_) => SyncCursorsCompanion(lastSeq: Value(seq))),
  );

  /// Drops a group's sync cursor so a later re-join backfills its whole history
  /// from the start rather than resuming past it.
  Future<void> clearCursor(String groupId) =>
      (delete(syncCursors)..where((c) => c.groupId.equals(groupId))).go();

  /// Drops any queued outbox entries for a group being removed locally.
  Future<void> clearOutboxFor(String groupId) =>
      (delete(outbox)..where((o) => o.groupId.equals(groupId))).go();

  /// Drops breadcrumb points older than [cutoff] for [ownerId].
  Future<int> purgeTrackBefore(String ownerId, DateTime cutoff) =>
      (delete(trackPoints)..where(
            (t) =>
                t.ownerId.equals(ownerId) &
                t.recordedAt.isSmallerThanValue(cutoff),
          ))
          .go();

  Future<List<TrackPoint>> trackSince(String ownerId, DateTime since) =>
      (select(trackPoints)
            ..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.recordedAt.isBiggerOrEqualValue(since),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.recordedAt)]))
          .get();
}
