import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fieldchat/app/connectivity.dart';
import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/brand/field_chat_logo.dart';
import 'package:fieldchat/features/capture/staged_point.dart';
import 'package:fieldchat/features/discovery/group_preview_screen.dart';
import 'package:fieldchat/features/discovery/public_directory.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/map/map_screen.dart';
import 'package:fieldchat/features/map/user_location.dart';
import 'package:fieldchat/features/messaging/presentation/chat_thread_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Map<int, Offset> _labelOffsets = const {};
  List<PublicGroup> _communities = const [];
  Map<int, Offset> _communityOffsets = const {};
  bool _showCommunities = false;
  bool _ready = false;
  LatLng? _myLocation;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeGroupsProvider, (_, _) => unawaited(_refreshAreas()));
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
                _controller = controller..onFeatureTapped.add(_onAreaTapped),
            onStyleLoadedCallback: _onStyleLoaded,
            onUserLocationUpdated: (location) => _myLocation = LatLng(
              location.position.latitude,
              location.position.longitude,
            ),
            onCameraIdle: _reposition,
          ),
          if (!_showCommunities)
            for (final entry in _labelOffsets.entries)
              _AreaLabel(
                area: _areas[entry.key],
                offset: entry.value,
                onTap: () => unawaited(_openGroup(_areas[entry.key].group)),
              ),
          if (_showCommunities)
            for (final entry in _communityOffsets.entries)
              _CommunityMarker(
                group: _communities[entry.key],
                offset: entry.value,
                onTap: () => _openCommunity(_communities[entry.key]),
              ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _showCommunities
                  ? (_communities.isEmpty && _ready
                        ? const _CommunitiesEmptyHint()
                        : const _TitleCard(
                            title: 'Communities nearby',
                            subtitle: 'Tap a group to preview and join',
                          ))
                  : (_areas.isEmpty && _ready
                        ? const _EmptyHint()
                        : const _TitleCard(
                            title: 'Your map areas',
                            subtitle: 'Tap an area to open its group map',
                          )),
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

  Future<void> _setView({required bool communities}) async {
    if (communities == _showCommunities) return;
    setState(() => _showCommunities = communities);
    final controller = _controller;
    if (communities) {
      // Hide the user's own areas while browsing public groups.
      await controller?.setGeoJsonSource('areas', {
        'type': 'FeatureCollection',
        'features': <dynamic>[],
      });
      await _loadCommunities();
    } else {
      await _refreshAreas();
    }
    await _reposition();
  }

  Future<void> _loadCommunities() async {
    final me = _myLocation ?? await currentUserLatLng();
    if (me == null) return;
    _myLocation = me;
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
    _ready = true;
    if (_areas.isEmpty) {
      await _centerOnMe();
    } else {
      await _frameAll();
    }
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

  /// Projects the active overlay's world points to screen offsets so the label
  /// cards or community markers sit over their locations. Runs on camera idle.
  Future<void> _reposition() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final media = MediaQuery.of(context);
    final ratio = defaultTargetPlatform == TargetPlatform.android
        ? media.devicePixelRatio
        : 1;
    final size = media.size;

    Future<Map<int, Offset>> project(List<LatLng> centers) async {
      final offsets = <int, Offset>{};
      for (var i = 0; i < centers.length; i++) {
        final screen = await controller.toScreenLocation(centers[i]);
        offsets[i] = Offset(
          (screen.x / ratio).clamp(98.0, size.width - 98.0),
          (screen.y / ratio).clamp(90.0, size.height - 90.0),
        );
      }
      return offsets;
    }

    if (_showCommunities) {
      final offsets = await project([
        for (final g in _communities) LatLng(g.centerLat, g.centerLng),
      ]);
      if (mounted) setState(() => _communityOffsets = offsets);
    } else {
      final offsets = await project([for (final a in _areas) a.center]);
      if (mounted) setState(() => _labelOffsets = offsets);
    }
  }

  void _onAreaTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != 'areas-fill') return;
    final index = int.tryParse(id);
    if (index == null || index < 0 || index >= _areas.length) return;
    unawaited(_openGroup(_areas[index].group));
  }

  Future<void> _openGroup(Group group) async {
    final staged = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => MapScreen(groupId: group.id, groupName: group.name),
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

String _plural(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';

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
    return Positioned(
      left: offset.dx - 90,
      top: offset.dy - 26,
      width: 180,
      child: Center(
        child: Material(
          color: area.hasAoi ? AppColors.ink : AppColors.white,
          borderRadius: BorderRadius.circular(9),
          elevation: 3,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          area.group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: area.hasAoi
                                ? AppColors.white
                                : AppColors.ink,
                          ),
                        ),
                        Text(
                          '${_plural(area.points, 'point')} · '
                          '${_plural(area.mappers, 'mapper')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: area.hasAoi
                                ? AppColors.white.withValues(alpha: 0.72)
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: area.hasAoi ? AppColors.white : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
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
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              label: 'Mine',
              selected: !showCommunities,
              enabled: true,
              onTap: () => onChanged(false),
            ),
            _Segment(
              label: 'Communities',
              selected: showCommunities,
              enabled: online,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.textFaint
        : (selected ? AppColors.white : AppColors.ink);
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// A public group pinned at its centre on the Map tab's Communities view.
class _CommunityMarker extends StatelessWidget {
  const _CommunityMarker({
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
      left: offset.dx - 90,
      top: offset.dy - 22,
      width: 180,
      child: Center(
        child: Material(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(9),
          elevation: 3,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.explore,
                    size: 14,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              'No public groups nearby',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Start a group and make it public to put it on the map for '
              'people around you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FieldChatMark(height: 40, color: AppColors.textFaint),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No areas yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Draw a mapping area or drop a few points in a group, '
              'and it lands here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
