import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/identity/admin_chain.dart';

/// Recomputes a group's verified admin set from its stored handshake events and
/// writes the result into member roles. Returns the verified admin ids. Before
/// the creator root key is known, the creator alone is treated as admin.
Future<Set<String>> recomputeAdmins(
  LocalDatabase db,
  String groupId,
) async {
  final group = await db.groupById(groupId);
  if (group == null) return const {};

  final rootKey = group.adminRootKey;
  if (rootKey == null || group.createdBy.isEmpty) {
    if (group.createdBy.isNotEmpty) {
      await db.setMemberRole(groupId, group.createdBy, 'admin');
      return {group.createdBy};
    }
    return const {};
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

  final admins = await verifiedAdmins(
    creatorId: group.createdBy,
    creatorPublic: base64Decode(rootKey),
    events: events,
  );
  for (final id in admins) {
    await db.setMemberRole(groupId, id, 'admin');
  }
  return admins;
}

/// Stores one incoming handshake event, then recomputes roles.
Future<void> applyAdminEvent(
  LocalDatabase db, {
  required String id,
  required String groupId,
  required int? seq,
  required String kind,
  required String actorId,
  required Uint8List actorPublic,
  required String subjectId,
  required Uint8List? subjectPublic,
  required Uint8List signature,
}) async {
  await db.insertAdminEvent(
    AdminEventsCompanion.insert(
      id: id,
      groupId: groupId,
      seq: Value(seq),
      kind: kind,
      actorId: actorId,
      actorPublic: base64Encode(actorPublic),
      subjectId: subjectId,
      subjectPublic: Value(
        subjectPublic == null ? null : base64Encode(subjectPublic),
      ),
      signature: base64Encode(signature),
    ),
  );
  await recomputeAdmins(db, groupId);
}
