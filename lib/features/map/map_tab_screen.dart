import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/connectivity.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/brand/hulaki_logo.dart';
import 'package:hulaki/design/widgets/pill_toggle.dart';
import 'package:hulaki/features/capture/staged_point.dart';
import 'package:hulaki/features/discovery/group_preview_screen.dart';
import 'package:hulaki/features/discovery/public_directory.dart';
import 'package:hulaki/features/export/geojson.dart';
import 'package:hulaki/features/map/map_screen.dart';
import 'package:hulaki/features/map/user_location.dart';
import 'package:hulaki/features/messaging/presentation/chat_thread_screen.dart';
import 'package:hulaki/l10n/app_localizations.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide buildFeatureCollection;

/// The Map tab: an overview of every group's mapping area. A group with a drawn
/// AOI shows that area; one without shows a box around its points. Tap an area
/// to open its live group map. (Prototype "Your map areas".)
class MapTabScreen extends ConsumerStatefulWidget {
  const MapTabScreen({super.key});

  static const _styleUrl =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  @override
  ConsumerState<MapTabScreen> createState() => _MapTabScreenState();
}

class _MapTabScreenState extends ConsumerState<MapTabScreen> {
  MapLibreMapController? _controller;
  List<_MapArea> _areas = const [];
  List<_AreaCluster> _areaClusters = const [];
  List<PublicGroup> _communities = const [];
  List<_CommunityCluster> _communityClusters = const [];
  bool _showCommunities = false;
  bool _ready = false;
  LatLng? _myLocation;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeGroupsProvider, (_, _) => unawaited(_refreshAreas()));
    final l10n = AppLocalizations.of(context);
    final online = ref.watch(onlineProvider);
    if (!online && _showCommunities) {
      _showCommunities = false;
    }

    return Scaffold(
      backgroundColor: AppColors.mist,
      body: Stack(
        children: [
          MapLibreMap(
            styleString: MapTabScreen._styleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(27.7051, 85.3051),
              zoom: 12,
            ),
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.compass,
            onMapCreated: (controller) =>
                _controller = controller..onFeatureTapped.add(_onFeatureTapped),
            onStyleLoadedCallback: _onStyleLoaded,
            onUserLocationUpdated: (location) => _myLocation = LatLng(
              location.position.latitude,
              location.position.longitude,
            ),
            onCameraIdle: _reposition,
          ),
          if (!_showCommunities)
            for (final cluster in _areaClusters)
              if (cluster.members.length == 1)
                _AreaLabel(
                  area: cluster.members.first,
                  offset: cluster.offset,
                  onTap: () => unawaited(
                    _openGroup(cluster.members.first, l10n.mapBack),
                  ),
                )
              else
                _CommunityClusterCard(
                  count: cluster.members.length,
                  offset: cluster.offset,
                  onTap: () => unawaited(
                    _expandCluster([
                      for (final m in cluster.members) m.center,
                    ]),
                  ),
                ),
          if (_showCommunities)
            for (final cluster in _communityClusters)
              if (cluster.members.length == 1)
                _CommunityCard(
                  group: cluster.members.first,
                  offset: cluster.offset,
                  onTap: () => _openCommunity(cluster.members.first),
                )
              else
                _CommunityClusterCard(
                  count: cluster.members.length,
                  offset: cluster.offset,
                  onTap: () => unawaited(
                    _expandCluster([
                      for (final m in cluster.members)
                        if (m.centerLat != null && m.centerLng != null)
                          LatLng(m.centerLat!, m.centerLng!),
                    ]),
                  ),
                ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _showCommunities
                  ? (_communities.isEmpty && _ready
                        ? const _CommunitiesEmptyHint()
                        : _TitleCard(
                            title: l10n.mapNearbyTitle,
                            subtitle: l10n.mapNearbySubtitle(25),
                          ))
                  : (_areas.isEmpty && _ready
                        ? const _EmptyHint()
                        : _TitleCard(
                            title: l10n.mapAreasTitle,
                            subtitle: l10n.mapAreasSubtitle,
                          )),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 92,
            child: Material(
              color: AppColors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                onTap: () => unawaited(_recenter()),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.my_location,
                    size: 22,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: _MapToggle(
                showCommunities: _showCommunities,
                online: online,
                onChanged: (value) => unawaited(_setView(communities: value)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Recenters the map, so it is always one tap back after panning or zooming
  /// out. On Nearby it reframes the whole 25 km search area; on My groups it
  /// centers on the user.
  Future<void> _recenter() async {
    final me = _myLocation ?? await currentUserLatLng();
    final controller = _controller;
    if (me == null || controller == null) return;
    _myLocation = me;
    if (_showCommunities) {
      await _frameRadius(me, 25);
    } else {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
    }
  }

  Future<void> _setView({required bool communities}) async {
    if (communities == _showCommunities) return;
    setState(() => _showCommunities = communities);
    final controller = _controller;
    if (communities) {
      // Hide the user's own areas while browsing public groups.
      await controller?.setGeoJsonSource('areas', _emptyCollection());
      await _loadCommunities();
    } else {
      await controller?.setGeoJsonSource('radius', _emptyCollection());
      await _refreshAreas();
    }
    await _reposition();
  }

  Future<void> _loadCommunities() async {
    final me = _myLocation ?? await currentUserLatLng();
    if (me == null) return;
    _myLocation = me;
    await _controller?.setGeoJsonSource('radius', {
      'type': 'FeatureCollection',
      'features': [_radiusRingFeature(me, 25)],
    });
    await _frameRadius(me, 25);
    final groups = await ref
        .read(publicDirectoryProvider)
        .nearby(lat: me.latitude, lng: me.longitude, radiusKm: 25);
    if (mounted) setState(() => _communities = groups);
  }

  void _openCommunity(PublicGroup group) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupPreviewScreen(group: group),
        ),
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
    await _refreshAreas();
    final controller = _controller;
    if (controller != null) {
      await controller.addGeoJsonSource('radius', _emptyCollection());
      await controller.addLineLayer(
        'radius',
        'radius-line',
        const LineLayerProperties(
          lineColor: '#E0922A',
          lineWidth: 1.5,
          lineOpacity: 0.7,
          lineDasharray: [2, 2],
        ),
      );
    }
    _ready = true;
    if (_areas.isEmpty) {
      await _centerOnMe();
    } else {
      await _frameAll();
    }
  }

  Map<String, dynamic> _emptyCollection() => {
    'type': 'FeatureCollection',
    'features': <dynamic>[],
  };

  /// Frames the whole 25 km search circle so the user sees how far Nearby
  /// reaches.
  Future<void> _frameRadius(LatLng center, double km) async {
    final controller = _controller;
    if (controller == null) return;
    final dLat = km * 1000 / 111320;
    final dLng =
        km * 1000 / (111320 * math.cos(center.latitude * math.pi / 180));
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(center.latitude - dLat, center.longitude - dLng),
          northeast: LatLng(center.latitude + dLat, center.longitude + dLng),
        ),
        left: 30,
        right: 30,
        top: 120,
        bottom: 90,
      ),
    );
  }

  Future<void> _centerOnMe() async {
    _myLocation ??= await currentUserLatLng();
    final me = _myLocation;
    final controller = _controller;
    if (me == null || controller == null) return;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
  }

  Future<void> _refreshAreas() async {
    final controller = _controller;
    if (controller == null) return;
    _areas = await _loadAreas(ref.read(databaseProvider));

    final collection = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': [
        for (var i = 0; i < _areas.length; i++) _areas[i].toFeature(i),
      ],
    };

    if (_ready) {
      await controller.setGeoJsonSource('areas', collection);
    } else {
      await controller.addGeoJsonSource('areas', collection);
      await controller.addFillLayer(
        'areas',
        'areas-fill',
        const FillLayerProperties(
          fillColor: [Expressions.get, 'fillColor'],
          fillOpacity: 0.12,
        ),
      );
      await controller.addLineLayer(
        'areas',
        'areas-outline',
        const LineLayerProperties(
          lineColor: [Expressions.get, 'strokeColor'],
          lineWidth: 1.6,
        ),
      );
    }
    await _reposition();
  }

  Future<void> _frameAll() async {
    final controller = _controller;
    if (controller == null || _areas.isEmpty) return;
    final lngs = [for (final a in _areas) ...a.corners.map((c) => c[0])];
    final lats = [for (final a in _areas) ...a.corners.map((c) => c[1])];
    final minLng = lngs.reduce(math.min);
    final maxLng = lngs.reduce(math.max);
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);

    if (maxLat - minLat < 0.004 && maxLng - minLng < 0.004) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          14,
        ),
      );
    } else {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: 40,
          right: 40,
          top: 120,
          bottom: 60,
        ),
      );
    }
    await _reposition();
  }

  /// Positions the overlay cards over their world points on camera idle. My
  /// groups place one label per area; communities are clustered client-side so
  /// nearby groups merge into a single "N groups" card instead of overlapping.
  Future<void> _reposition() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final media = MediaQuery.of(context);
    final ratio = defaultTargetPlatform == TargetPlatform.android
        ? media.devicePixelRatio
        : 1;
    final size = media.size;

    Future<Offset?> project(LatLng at) async {
      final screen = await controller.toScreenLocation(at);
      final dx = screen.x / ratio;
      final dy = screen.y / ratio;
      // Skip points off screen so cards do not pile up at the edges.
      if (dx < -40 ||
          dx > size.width + 40 ||
          dy < -40 ||
          dy > size.height + 40) {
        return null;
      }
      return Offset(
        dx.clamp(96.0, size.width - 96.0),
        dy.clamp(90.0, size.height - 90.0),
      );
    }

    if (_showCommunities) {
      final placed = <(Offset, LatLng)>[];
      for (final group in _communities) {
        final lat = group.centerLat;
        final lng = group.centerLng;
        if (lat == null || lng == null) continue;
        final center = LatLng(lat, lng);
        final offset = await project(center);
        placed.add((offset ?? Offset.infinite, center));
      }
      final clusters = <_CommunityCluster>[];
      for (final group in _clusterByProximity(placed)) {
        clusters.add(
          _CommunityCluster(
            offset: group.offset,
            center: group.center,
            members: [for (final i in group.indices) _communities[i]],
          ),
        );
      }
      if (mounted) setState(() => _communityClusters = clusters);
      return;
    }

    final placed = <(Offset, LatLng)>[];
    for (final area in _areas) {
      final offset = await project(area.center);
      placed.add((offset ?? Offset.infinite, area.center));
    }
    final clusters = <_AreaCluster>[];
    for (final group in _clusterByProximity(placed)) {
      clusters.add(
        _AreaCluster(
          offset: group.offset,
          center: group.center,
          members: [for (final i in group.indices) _areas[i]],
        ),
      );
    }
    if (mounted) setState(() => _areaClusters = clusters);
  }

  /// Greedily merges cards whose screen positions are within a card's width of
  /// each other, so a dense area shows one count card that splits into
  /// individual cards as the user zooms in. Off-screen points (infinite offset)
  /// are dropped.
  List<({Offset offset, LatLng center, List<int> indices})> _clusterByProximity(
    List<(Offset, LatLng)> placed,
  ) {
    const threshold = 76.0;
    final onScreen = [
      for (var i = 0; i < placed.length; i++)
        if (placed[i].$1.isFinite) i,
    ];
    final used = <int>{};
    final clusters = <({Offset offset, LatLng center, List<int> indices})>[];
    for (final i in onScreen) {
      if (used.contains(i)) continue;
      used.add(i);
      final indices = <int>[i];
      var sumX = placed[i].$1.dx;
      var sumY = placed[i].$1.dy;
      for (final j in onScreen) {
        if (used.contains(j)) continue;
        if ((placed[i].$1 - placed[j].$1).distance <= threshold) {
          used.add(j);
          indices.add(j);
          sumX += placed[j].$1.dx;
          sumY += placed[j].$1.dy;
        }
      }
      final n = indices.length;
      clusters.add((
        offset: Offset(sumX / n, sumY / n),
        center: LatLng(
          indices.map((k) => placed[k].$2.latitude).reduce((a, b) => a + b) / n,
          indices.map((k) => placed[k].$2.longitude).reduce((a, b) => a + b) /
              n,
        ),
        indices: indices,
      ));
    }
    return clusters;
  }

  Future<void> _expandCluster(List<LatLng> centers) async {
    final controller = _controller;
    if (controller == null || centers.isEmpty) return;
    var minLat = centers.first.latitude;
    var maxLat = minLat;
    var minLng = centers.first.longitude;
    var maxLng = minLng;
    for (final c in centers) {
      minLat = c.latitude < minLat ? c.latitude : minLat;
      maxLat = c.latitude > maxLat ? c.latitude : maxLat;
      minLng = c.longitude < minLng ? c.longitude : minLng;
      maxLng = c.longitude > maxLng ? c.longitude : maxLng;
    }
    if (maxLat - minLat < 0.0005 && maxLng - minLng < 0.0005) {
      final zoom = ((controller.cameraPosition?.zoom ?? 11) + 3).clamp(
        1.0,
        18.0,
      );
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(centers.first, zoom),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 60,
        right: 60,
        top: 160,
        bottom: 180,
      ),
    );
  }

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != 'areas-fill') return;
    final index = int.tryParse(id);
    if (index == null || index < 0 || index >= _areas.length) return;
    unawaited(
      _openGroup(_areas[index], AppLocalizations.of(context).mapBack),
    );
  }

  Future<void> _openGroup(_MapArea area, String backLabel) async {
    final group = area.group;
    final center = area.center;
    final staged = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => MapScreen(
          groupId: group.id,
          groupName: group.name,
          backLabel: backLabel,
          initialLat: center.latitude,
          initialLng: center.longitude,
        ),
      ),
    );
    // A point tapped on the group map opens its thread, staged to drop there.
    if (staged is StagedPoint && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            groupId: group.id,
            groupName: group.name,
            stagedPoint: staged,
          ),
        ),
      );
    }
  }
}

/// Reads every active group and turns those with an area or points into a
/// drawable [_MapArea]. Groups with neither are left off the map.
Future<List<_MapArea>> _loadAreas(LocalDatabase db) async {
  final groups = await db.activeGroups();
  final areas = <_MapArea>[];
  for (final group in groups) {
    final messages = await db.messagesFor(group.id);
    final located = messages
        .where((m) => m.lat != null && m.lng != null && m.deletedAt == null)
        .toList();
    final mappers = located.map((m) => m.senderId).toSet().length;

    final aoi = group.aoiGeoJson;
    if (aoi != null) {
      final bounds = aoiBounds(aoi);
      if (bounds != null) {
        areas.add(
          _MapArea(
            group: group,
            geometry: _firstGeometry(aoi),
            corners: _cornersOf(bounds),
            points: located.length,
            mappers: mappers,
          ),
        );
        continue;
      }
    }

    if (located.isEmpty) continue;
    final bounds = _paddedBounds(located);
    areas.add(
      _MapArea(
        group: group,
        geometry: {
          'type': 'Polygon',
          'coordinates': [_cornersOf(bounds)],
        },
        corners: _cornersOf(bounds),
        points: located.length,
        mappers: mappers,
      ),
    );
  }
  return areas;
}

Map<String, dynamic> _firstGeometry(String geoJson) {
  final decoded = jsonDecode(geoJson);
  if (decoded is Map && decoded['type'] == 'FeatureCollection') {
    return ((decoded['features'] as List).first as Map)['geometry']
        as Map<String, dynamic>;
  }
  if (decoded is Map && decoded['type'] == 'Feature') {
    return decoded['geometry'] as Map<String, dynamic>;
  }
  return (decoded as Map).cast<String, dynamic>();
}

/// A points-only group gets a box around its fixes, padded so a single point
/// still draws a visible area.
List<double> _paddedBounds(List<Message> located) {
  final lngs = located.map((m) => m.lng!).toList();
  final lats = located.map((m) => m.lat!).toList();
  const pad = 0.0009;
  return [
    lngs.reduce(math.min) - pad,
    lats.reduce(math.min) - pad,
    lngs.reduce(math.max) + pad,
    lats.reduce(math.max) + pad,
  ];
}

/// A closed rectangle ring [lng,lat] from bounds [minLng,minLat,maxLng,maxLat].
List<List<double>> _cornersOf(List<double> bounds) {
  final (minLng, minLat, maxLng, maxLat) = (
    bounds[0],
    bounds[1],
    bounds[2],
    bounds[3],
  );
  return [
    [minLng, minLat],
    [maxLng, minLat],
    [maxLng, maxLat],
    [minLng, maxLat],
    [minLng, minLat],
  ];
}

/// A GeoJSON ring approximating a [km] circle around [center], drawn on the
/// Nearby view so the search radius is visible, not just described.
Map<String, dynamic> _radiusRingFeature(LatLng center, double km) {
  const steps = 72;
  final metres = km * 1000;
  final latRad = center.latitude * math.pi / 180;
  final ring = <List<double>>[
    for (var i = 0; i <= steps; i++)
      [
        center.longitude +
            (metres * math.sin(2 * math.pi * i / steps)) /
                (111320 * math.cos(latRad)),
        center.latitude + (metres * math.cos(2 * math.pi * i / steps)) / 111320,
      ],
  ];
  return {
    'type': 'Feature',
    'properties': <String, dynamic>{},
    'geometry': {
      'type': 'Polygon',
      'coordinates': [ring],
    },
  };
}

class _MapArea {
  const _MapArea({
    required this.group,
    required this.geometry,
    required this.corners,
    required this.points,
    required this.mappers,
  });

  final Group group;
  final Map<String, dynamic> geometry;
  final List<List<double>> corners;
  final int points;
  final int mappers;

  bool get hasAoi => group.aoiGeoJson != null;

  LatLng get center {
    final lng = (corners[0][0] + corners[2][0]) / 2;
    final lat = (corners[0][1] + corners[2][1]) / 2;
    return LatLng(lat, lng);
  }

  Map<String, dynamic> toFeature(int index) => {
    'type': 'Feature',
    'id': index,
    'properties': {
      'fillColor': hasAoi ? '#E0922A' : '#8C887F',
      'strokeColor': hasAoi ? '#E0922A' : '#8C887F',
    },
    'geometry': geometry,
  };
}

class _AreaLabel extends StatelessWidget {
  const _AreaLabel({
    required this.area,
    required this.offset,
    required this.onTap,
  });

  final _MapArea area;
  final Offset offset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: offset.dx - 92,
      top: offset.dy - 26,
      width: 184,
      child: Center(
        child: _MapCard(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 15,
                color: AppColors.ink,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      area.group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      l10n.mapAreaSummary(area.points, area.mappers),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared card used for every marker overlay on the map tabs, so groups,
/// communities and clusters look identical: a light card with a hairline
/// border and a soft shadow.
class _MapCard extends StatelessWidget {
  const _MapCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: AppColors.ink.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: AppColors.mist),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: child,
        ),
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: AppColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Mine / Communities switch at the bottom of the Map tab. The Communities
/// side is disabled while offline, since discovery needs the network.
class _MapToggle extends StatelessWidget {
  const _MapToggle({
    required this.showCommunities,
    required this.online,
    required this.onChanged,
  });

  final bool showCommunities;
  final bool online;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PillToggle(
      left: l10n.mapToggleMyGroups,
      right: l10n.mapToggleCommunities,
      rightSelected: showCommunities,
      rightEnabled: online,
      elevation: 4,
      onChanged: onChanged,
    );
  }
}

/// One card on the Communities map: a single group, or a merged group of
/// nearby ones with a shared screen position and geographic centre.
class _CommunityCluster {
  const _CommunityCluster({
    required this.offset,
    required this.members,
    required this.center,
  });

  final Offset offset;
  final List<PublicGroup> members;
  final LatLng center;
}

/// One card on the My-groups map: a single area, or nearby areas merged so far
/// apart groups do not all cram the screen at once.
class _AreaCluster {
  const _AreaCluster({
    required this.offset,
    required this.members,
    required this.center,
  });

  final Offset offset;
  final List<_MapArea> members;
  final LatLng center;
}

/// A single public group shown as a clean grey card over its location.
class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.group,
    required this.offset,
    required this.onTap,
  });

  final PublicGroup group;
  final Offset offset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx - 92,
      top: offset.dy - 18,
      width: 184,
      child: Center(
        child: _MapCard(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 15,
                color: AppColors.ink,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A merged group of nearby communities, shown as a grey count card that
/// zooms in to split apart when tapped.
class _CommunityClusterCard extends StatelessWidget {
  const _CommunityClusterCard({
    required this.count,
    required this.offset,
    required this.onTap,
  });

  final int count;
  final Offset offset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: offset.dx - 70,
      top: offset.dy - 18,
      width: 140,
      child: Center(
        child: _MapCard(
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.mapClusterGroups,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunitiesEmptyHint extends StatelessWidget {
  const _CommunitiesEmptyHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.explore_outlined,
              size: 40,
              color: AppColors.textFaint,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.mapNoNearbyGroupsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.mapNoNearbyGroupsBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HulakiMark(height: 40, color: AppColors.textFaint),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.mapNoAreasTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.mapNoAreasBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
