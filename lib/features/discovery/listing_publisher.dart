import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/core/image_thumbnail.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/features/discovery/public_directory.dart';
import 'package:hulaki/features/export/geojson.dart';

/// Writes a group's public listing (name, description, centre, tags) to the
/// directory. The mapper count is maintained server-side from the group's
/// envelopes, so it is not written here.
Future<void> publishGroupListing(
  WidgetRef ref,
  Group group,
  (double, double)? center,
) async {
  final db = ref.read(databaseProvider);
  final hotKeys = await db.hotKeysFor(group.id);
  final photo = group.photo;
  await ref
      .read(publicDirectoryProvider)
      .publish(
        PublicGroup(
          groupId: group.id,
          name: group.name,
          scope: group.scope,
          description: group.description,
          centerLat: center?.$1,
          centerLng: center?.$2,
          // Approval-gated groups withhold the key so joining requires an admin
          // to seal it back to the approved requester.
          encKey: group.joinApproval ? '' : group.encKey,
          joinApproval: group.joinApproval,
          photo: photo == null
              ? null
              : squareJpegThumbnail(photo, size: 256, quality: 75),
          tags: [
            for (final hotKey in hotKeys)
              DirectoryTag(
                label: hotKey.label,
                colorValue: hotKey.colorValue,
                iconName: hotKey.iconName,
              ),
          ],
          aoiGeoJson: group.aoiGeoJson,
        ),
      );
}

/// Republishes the listing for a public group when the caller is an admin, so
/// the directory stays in step with the group's name, tags, and area. A no-op
/// for private groups and non-admins. A global group needs no location; a local
/// group is skipped until it has a locatable centre.
Future<void> refreshPublicListing(WidgetRef ref, String groupId) async {
  final db = ref.read(databaseProvider);
  final group = await db.groupById(groupId);
  if (group == null || !group.isPublic) return;
  final selfId = ref.read(currentUserIdProvider);
  final members = await db.watchMembersFor(groupId).first;
  if (!members.any((m) => m.profileId == selfId && m.isAdmin)) return;
  if (group.scope == 'global') {
    await publishGroupListing(ref, group, null);
    return;
  }
  final center = await _listingCenter(db, groupId, group.aoiGeoJson);
  if (center == null) return;
  await publishGroupListing(ref, group, center);
}

/// The group's map centre: the area's midpoint, else the average of its points.
/// Null when the group has neither, so it cannot be listed.
Future<(double, double)?> _listingCenter(
  LocalDatabase db,
  String groupId,
  String? aoiGeoJson,
) async {
  final bounds = aoiBounds(aoiGeoJson);
  if (bounds != null) {
    return ((bounds[1] + bounds[3]) / 2, (bounds[0] + bounds[2]) / 2);
  }
  final messages = await db.messagesFor(groupId);
  final located = messages
      .where((m) => m.lat != null && m.lng != null)
      .toList();
  if (located.isEmpty) return null;
  final lat =
      located.map((m) => m.lat!).reduce((a, b) => a + b) / located.length;
  final lng =
      located.map((m) => m.lng!).reduce((a, b) => a + b) / located.length;
  return (lat, lng);
}
