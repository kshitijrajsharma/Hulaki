import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/sync/group_cipher.dart';
import 'package:hulaki/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Seeds a local, never-published sample group near [centerLat] / [centerLng]
/// so a first-time user starts with a populated chat and map. Returns the id.
Future<String> seedDemoGroup(
  LocalDatabase db,
  String userId,
  AppLocalizations l10n, {
  required double centerLat,
  required double centerLng,
}) async {
  const uuid = Uuid();
  final groupId = uuid.v4();

  await db
      .into(db.groups)
      .insert(
        GroupsCompanion.insert(
          id: groupId,
          name: l10n.demoGroupName,
          // A sample profile owns the group so the newcomer experiences it as a
          // member (fewer controls), while member export stays on so the
          // tutorial can still show exporting the data.
          createdBy: 'demo-ashi',
          encKey: base64Encode(await GroupCipher.generateKey()),
          isSample: const Value(true),
          allowMemberExport: const Value(true),
        ),
      );

  // The four default quick tags, so the sample teaches the tags they will use.
  final tagSpecs = <(String, String, int, String)>[
    ('trash', l10n.groupDefaultTagTrash, 0xFF15181B, 'delete'),
    ('crossing', l10n.groupDefaultTagCrossings, 0xFFE0922A, 'crossing'),
    ('streetlight', l10n.groupDefaultTagStreetlight, 0xFF7B6FC4, 'streetlight'),
    ('pole', l10n.groupDefaultTagPole, 0xFFC4615E, 'bolt'),
  ];
  final tagIds = <String, String>{};
  for (var i = 0; i < tagSpecs.length; i++) {
    final (key, label, color, icon) = tagSpecs[i];
    final id = uuid.v4();
    tagIds[key] = id;
    await db
        .into(db.hotKeys)
        .insert(
          HotKeysCompanion.insert(
            id: id,
            groupId: groupId,
            label: label,
            colorValue: color,
            iconName: Value(icon),
            position: Value(i),
          ),
        );
  }

  for (final (id, name) in [('demo-ashi', 'Ashi'), ('demo-bishe', 'Bishe')]) {
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(id: id, phone: '', displayName: Value(name)),
          mode: InsertMode.insertOrIgnore,
        );
  }
  await db
      .into(db.profiles)
      .insert(
        ProfilesCompanion.insert(id: userId, phone: ''),
        mode: InsertMode.insertOrIgnore,
      );
  final memberRoles = {
    'demo-ashi': 'admin',
    'demo-bishe': 'member',
    userId: 'member',
  };
  for (final entry in memberRoles.entries) {
    await db
        .into(db.groupMembers)
        .insert(
          GroupMembersCompanion.insert(
            groupId: groupId,
            profileId: entry.key,
            role: Value(entry.value),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  // One point carries a real photo; the rest are text, to keep the sample tiny.
  final mediaId = uuid.v4();
  final photo = (await rootBundle.load(
    'assets/demo/crossing.jpg',
  )).buffer.asUint8List();
  await db
      .into(db.mediaBlobs)
      .insert(
        MediaBlobsCompanion.insert(
          id: mediaId,
          bytes: photo,
          mime: 'image/jpeg',
        ),
      );

  // Small offsets in degrees (roughly 60 to 150 m) so the points cluster like
  // a neighbourhood around the user rather than landing on one spot.
  final now = DateTime.now();
  final points = <(String, String, String, double, double, String?, int)>[
    (
      'demo-ashi',
      'crossing',
      l10n.demoPointCrossing,
      0.0009,
      0.0007,
      mediaId,
      38,
    ),
    ('demo-bishe', 'trash', l10n.demoPointTrash, -0.0006, -0.0010, null, 31),
    (
      'demo-ashi',
      'streetlight',
      l10n.demoPointStreetlight,
      0.0012,
      -0.0004,
      null,
      22,
    ),
    ('demo-bishe', 'pole', l10n.demoPointPole, -0.0011, 0.0009, null, 12),
    ('demo-ashi', 'trash', l10n.demoPointDumping, 0.0004, 0.0013, null, 4),
  ];
  for (final (sender, tag, note, dLat, dLng, media, minsAgo) in points) {
    final lat = centerLat + dLat;
    final lng = centerLng + dLng;
    await db
        .into(db.messages)
        .insert(
          MessagesCompanion.insert(
            id: uuid.v4(),
            groupId: groupId,
            senderId: sender,
            kind: media == null ? 'text' : 'photo',
            body: Value(note),
            tagId: Value(tagIds[tag]),
            lat: Value(lat),
            lng: Value(lng),
            accuracyM: const Value(5),
            mediaId: Value(media),
            mediaMime: media == null
                ? const Value.absent()
                : const Value('image/jpeg'),
            createdAt: now.subtract(Duration(minutes: minsAgo)),
            sendState: const Value('sent'),
          ),
        );
  }

  return groupId;
}

/// Removes the local sample group and everything it seeded. Purely local, since
/// the sample never reached the backend.
Future<void> removeSampleGroup(LocalDatabase db, String groupId) async {
  for (final message in await db.messagesFor(groupId)) {
    final mediaId = message.mediaId;
    if (mediaId != null) {
      await (db.delete(db.mediaBlobs)..where((b) => b.id.equals(mediaId))).go();
    }
  }
  await (db.delete(db.messages)..where((m) => m.groupId.equals(groupId))).go();
  await (db.delete(db.hotKeys)..where((h) => h.groupId.equals(groupId))).go();
  await (db.delete(
    db.groupMembers,
  )..where((gm) => gm.groupId.equals(groupId))).go();
  await (db.delete(db.groups)..where((g) => g.id.equals(groupId))).go();
}
