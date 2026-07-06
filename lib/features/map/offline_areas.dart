import 'dart:async';

import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide buildFeatureCollection;

/// Offline tiles are a cache, not permanent storage: an area is dropped this
/// long after it was downloaded so stale basemaps do not pile up.
const kOfflineTtl = Duration(days: 30);

/// The key-free OSM vector basemap, shared by the map screens and the offline
/// cache so a downloaded area renders the same tiles it was cached from.
const kOsmStyleUrl =
    'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

/// The area to cache for a group: its drawn AOI if present, otherwise a box
/// around its located points. Null when the group has neither.
Future<LatLngBounds?> groupBounds(LocalDatabase db, String groupId) async {
  final group = await db.groupById(groupId);
  final aoi = group?.aoiGeoJson;
  if (aoi != null) {
    final b = aoiBounds(aoi);
    if (b != null) {
      return LatLngBounds(
        southwest: LatLng(b[1], b[0]),
        northeast: LatLng(b[3], b[2]),
      );
    }
  }

  final located = (await db.messagesFor(groupId))
      .where((m) => m.lat != null && m.lng != null && m.deletedAt == null)
      .toList();
  if (located.isEmpty) return null;
  final lats = located.map((m) => m.lat!);
  final lngs = located.map((m) => m.lng!);
  const pad = 0.003;
  return LatLngBounds(
    southwest: LatLng(
      lats.reduce((a, b) => a < b ? a : b) - pad,
      lngs.reduce((a, b) => a < b ? a : b) - pad,
    ),
    northeast: LatLng(
      lats.reduce((a, b) => a > b ? a : b) + pad,
      lngs.reduce((a, b) => a > b ? a : b) + pad,
    ),
  );
}

/// Downloads the group's basemap tiles for offline use, tagged with the group
/// and download time so it can be listed, sized, expired, and removed later.
/// Completes when every tile is cached; [onProgress] reports 0..1 meanwhile.
Future<void> cacheGroupOffline({
  required String groupId,
  required String groupName,
  required LatLngBounds bounds,
  void Function(double progress)? onProgress,
}) async {
  // Replace any earlier download for this group so re-caching refreshes the
  // tiles instead of leaving a stale duplicate region behind.
  for (final region in await cachedGroupRegions()) {
    if (region.metadata['group'] == groupId) {
      await removeCachedRegion(region.id);
    }
  }
  final done = Completer<void>();
  await downloadOfflineRegion(
    OfflineRegionDefinition(
      bounds: bounds,
      minZoom: 12,
      maxZoom: 17,
      mapStyleUrl: kOsmStyleUrl,
    ),
    metadata: {
      'group': groupId,
      'name': groupName,
      'downloadedAt': DateTime.now().toIso8601String(),
    },
    onEvent: (event) {
      switch (event) {
        case InProgress(
          :final completedResourceCount,
          :final requiredResourceCount,
        ):
          final fraction = requiredResourceCount > 0
              ? completedResourceCount / requiredResourceCount
              : 0.0;
          onProgress?.call(fraction.clamp(0.0, 1.0));
        case Success():
          if (!done.isCompleted) done.complete();
        case Error(:final cause):
          if (!done.isCompleted) done.completeError(cause);
      }
    },
  );
  return done.future;
}

/// A cached area belonging to a group: its size on disk and when it expires.
class CachedArea {
  const CachedArea({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.expiresAt,
  });

  final int id;
  final String name;
  final int sizeBytes;
  final DateTime? expiresAt;
}

/// The cached regions that belong to a FieldChat group.
Future<List<OfflineRegion>> cachedGroupRegions() async {
  final regions = await getListOfRegions();
  return regions.where((r) => r.metadata['group'] != null).toList();
}

/// The cached areas with size and expiry, dropping any past their TTL so the
/// list only ever shows live downloads.
Future<List<CachedArea>> cachedGroupAreas() async {
  final now = DateTime.now();
  final areas = <CachedArea>[];
  for (final region in await cachedGroupRegions()) {
    final downloadedAt = DateTime.tryParse(
      region.metadata['downloadedAt']?.toString() ?? '',
    );
    final expiresAt = downloadedAt?.add(kOfflineTtl);
    if (expiresAt != null && expiresAt.isBefore(now)) {
      await removeCachedRegion(region.id);
      continue;
    }
    final status = await getOfflineRegionStatus(region.id);
    areas.add(
      CachedArea(
        id: region.id,
        name: region.metadata['name']?.toString() ?? 'Area',
        sizeBytes: status.completedResourceSize,
        expiresAt: expiresAt,
      ),
    );
  }
  return areas;
}

Future<void> removeCachedRegion(int id) => deleteOfflineRegion(id);
