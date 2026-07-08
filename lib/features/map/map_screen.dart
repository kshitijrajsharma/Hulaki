import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/capture/location_permission.dart';
import 'package:fieldchat/features/capture/presentation/live_gps_strip.dart';
import 'package:fieldchat/features/capture/staged_point.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/groups/hot_key_icons.dart';
import 'package:fieldchat/features/map/map_tap_sheet.dart';
import 'package:fieldchat/features/map/marker_images.dart';
import 'package:fieldchat/features/map/point_sheet.dart';
import 'package:fieldchat/features/map/user_location.dart';
import 'package:fieldchat/features/onboarding/coach_tip.dart';
import 'package:fieldchat/features/track/track_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart'
    show Geolocator, LocationSettings, Position;
import 'package:maplibre_gl/maplibre_gl.dart' hide buildFeatureCollection;

/// The shared map for a group: every located message is a tag-coloured pin over
/// the breadcrumb track. Reached by the Map button in the thread. Tap a pin for
/// its detail; the heading arrow reads the device compass, so it turns with no
/// GPS. The basemap switches between an OSM vector style and satellite imagery.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({
    required this.groupId,
    required this.groupName,
    this.focusMessageId,
    super.key,
  });

  final String groupId;
  final String groupName;

  /// When set, the map centers on this point and opens its detail sheet once
  /// the pins are ready. Used when arriving from a point's mini-map.
  final String? focusMessageId;

  static const _osmStyle =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  static const _esriTiles =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static const _glyphs =
      'https://tiles.basemaps.cartocdn.com/fonts/{fontstack}/{range}.pbf';

  static final String _satelliteStyle = jsonEncode({
    'version': 8,
    'glyphs': _glyphs,
    'sources': {
      'esri': {
        'type': 'raster',
        'tiles': [_esriTiles],
        'tileSize': 256,
        'attribution': 'Imagery (c) Esri',
      },
    },
    'layers': [
      {'id': 'esri', 'type': 'raster', 'source': 'esri'},
    ],
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _controller;
  StreamSubscription<Position>? _positionSub;
  TrackRecorder? _tracker;
  bool _sourcesReady = false;
  bool _styledOnce = false;
  bool _satellite = false;
  String? _aoiGeoJson;
  bool _canPlace = true;
  bool _outsideAoi = false;
  bool _aoiInView = false;
  LatLng? _lastLocation;
  List<Message> _pointMessages = const [];
  Map<String, HotKey> _hotKeysById = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_startTracking());
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    super.dispose();
  }

  Future<void> _startTracking() async {
    if (!await ensureLocationPermission()) return;
    _tracker = TrackRecorder(ref.read(databaseProvider));
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 5),
    ).listen(_onPosition);
  }

  Future<void> _onPosition(Position position) async {
    if (!mounted) return;
    final stored = await _tracker?.record(
      ownerId: ref.read(currentUserIdProvider),
      fix: GpsFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy,
      ),
      at: DateTime.now(),
    );
    _updateLocation(position.latitude, position.longitude);
    if (!mounted || !_sourcesReady) return;
    if (stored ?? false) {
      await _controller?.setGeoJsonSource('track', await _trackLine());
    }
  }

  /// Records the latest fix for the recenter button and flags whether it sits
  /// outside the task area. Fed by both the position stream and the map's own
  /// location puck, so it holds whichever reports first.
  void _updateLocation(double lat, double lng) {
    _lastLocation = LatLng(lat, lng);
    final aoi = _aoiGeoJson;
    if (aoi == null) return;
    final outside = !pointInAoi(aoi, lat, lng);
    if (outside != _outsideAoi && mounted) {
      setState(() => _outsideAoi = outside);
    }
  }

  /// Tracks whether the task area is currently within the map viewport, so the
  /// "zoom to task area" prompt hides once the area is on screen.
  Future<void> _onCameraIdle() async {
    final aoi = _aoiGeoJson;
    final controller = _controller;
    if (aoi == null || controller == null) return;
    final bounds = aoiBounds(aoi);
    if (bounds == null) return;
    final view = await controller.getVisibleRegion();
    final inView = _boundsIntersect(view, bounds);
    if (inView != _aoiInView && mounted) {
      setState(() => _aoiInView = inView);
    }
  }

  /// Whether the area box [minLng, minLat, maxLng, maxLat] overlaps [view].
  bool _boundsIntersect(LatLngBounds view, List<double> aoi) {
    return !(aoi[2] < view.southwest.longitude ||
        aoi[0] > view.northeast.longitude ||
        aoi[3] < view.southwest.latitude ||
        aoi[1] > view.northeast.latitude);
  }

  /// Centers the camera on the latest known location, if any.
  Future<void> _recenter() async {
    final target = _lastLocation;
    if (target == null) return;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messagesProvider(widget.groupId), (_, _) => _refreshPins());

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _satellite
                ? MapScreen._satelliteStyle
                : MapScreen._osmStyle,
            initialCameraPosition: const CameraPosition(
              target: LatLng(27.7051, 85.3051),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.compass,
            onMapCreated: (controller) =>
                _controller = controller..onFeatureTapped.add(_onFeatureTapped),
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: (point, coordinates) =>
                unawaited(_onMapTapped(coordinates)),
            onUserLocationUpdated: (location) => _updateLocation(
              location.position.latitude,
              location.position.longitude,
            ),
            onCameraIdle: () => unawaited(_onCameraIdle()),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: _RecenterButton(onTap: () => unawaited(_recenter())),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _MapHeader(
                    groupName: widget.groupName,
                    satellite: _satellite,
                    onToggleBasemap: _toggleBasemap,
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(11),
                    elevation: 2,
                    child: const LiveGpsStrip(),
                  ),
                  const CoachTip(
                    tipKey: 'map',
                    translucent: true,
                    message:
                        'Tap a point to open it. Tap the crosshair to '
                        'jump to your location.',
                  ),
                ],
              ),
            ),
          ),
          if (_outsideAoi && !_aoiInView)
            Positioned(
              left: 0,
              right: 0,
              bottom: 44,
              child: Center(
                child: _ZoomToAreaPill(onTap: () => unawaited(_frameAoi())),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleBasemap() async {
    _sourcesReady = false;
    setState(() => _satellite = !_satellite);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;

    final group = await ref.read(databaseProvider).groupById(widget.groupId);
    final aoi = group?.aoiGeoJson;
    _aoiGeoJson = aoi;
    _canPlace =
        (group?.allowMemberPlace ?? true) ||
        ref.read(isGroupAdminProvider(widget.groupId));
    if (aoi != null) {
      await controller.addGeoJsonSource(
        'aoi',
        jsonDecode(aoi) as Map<String, dynamic>,
      );
      await controller.addFillLayer(
        'aoi',
        'aoi-fill',
        const FillLayerProperties(fillColor: '#E0922A', fillOpacity: 0.10),
      );
      await controller.addLineLayer(
        'aoi',
        'aoi-outline',
        const LineLayerProperties(lineColor: '#E0922A', lineWidth: 1.5),
      );
    }

    await controller.addGeoJsonSource('track', await _trackLine());
    await controller.addLineLayer(
      'track',
      'track-line',
      const LineLayerProperties(
        lineColor: '#9A968D',
        lineWidth: 3,
        lineOpacity: 0.6,
        lineCap: 'round',
        lineDasharray: [0.2, 2.2],
      ),
    );

    await _ensurePinImages();
    final collection = await _featureCollection();
    await controller.addSource(
      'points',
      GeojsonSourceProperties(
        data: collection,
        cluster: true,
        clusterMaxZoom: 16,
      ),
    );
    // Clustered groups: a dark bubble whose size steps up with the count.
    await controller.addCircleLayer(
      'points',
      'clusters',
      const CircleLayerProperties(
        circleColor: '#15181B',
        circleRadius: [
          Expressions.step,
          [Expressions.get, 'point_count'],
          15.0,
          10,
          20.0,
          25,
          26.0,
        ],
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2,
        circleOpacity: 0.92,
      ),
      filter: ['has', 'point_count'],
    );
    await controller.addSymbolLayer(
      'points',
      'cluster-count',
      const SymbolLayerProperties(
        textField: [Expressions.get, 'point_count_abbreviated'],
        textFont: ['Open Sans Regular'],
        textSize: 13,
        textColor: '#ffffff',
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
      filter: ['has', 'point_count'],
      enableInteraction: false,
    );
    // Single points: the tag-coloured icon pin.
    await controller.addSymbolLayer(
      'points',
      'points-symbols',
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'icon'],
        iconSize: 1,
        iconAnchor: 'bottom',
        iconAllowOverlap: true,
      ),
      filter: [
        '!',
        ['has', 'point_count'],
      ],
    );
    await controller.addGeoJsonSource('tap', _emptyFeatures());
    await controller.addCircleLayer(
      'tap',
      'tap-marker',
      const CircleLayerProperties(
        circleRadius: 7,
        circleColor: '#2F6BFF',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
        circleOpacity: 0.9,
      ),
    );
    _sourcesReady = true;

    // Framing and the focused-point sheet belong to the first load only. A
    // basemap toggle reloads the style and must not reopen the sheet or move
    // the camera the user just positioned.
    if (_styledOnce) return;
    _styledOnce = true;

    final focusId = widget.focusMessageId;
    if (focusId != null && await _focusMessage(focusId)) return;

    if ((collection['features'] as List).isNotEmpty) {
      await _centerOnData(collection);
    } else if (_aoiGeoJson != null) {
      await _frameAoi();
    } else {
      await _centerOnMe();
    }
  }

  Future<void> _centerOnMe() async {
    final me = _lastLocation ?? await currentUserLatLng();
    if (me == null) return;
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
  }

  /// Frames the group's task area, if it has one.
  Future<void> _frameAoi() async {
    final aoi = _aoiGeoJson;
    if (aoi == null) return;
    final bounds = aoiBounds(aoi);
    if (bounds == null) return;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds[1], bounds[0]),
          northeast: LatLng(bounds[3], bounds[2]),
        ),
        left: 40,
        right: 40,
        top: 140,
        bottom: 40,
      ),
    );
  }

  /// A tap on empty map: offer to place a point here (staged into the composer)
  /// or navigate to it. Pins and clusters fire [_onFeatureTapped] instead, as
  /// featureTapsTriggersMapClick defaults to false.
  Future<void> _onMapTapped(LatLng coordinates) async {
    if (!mounted) return;
    if (_sourcesReady) {
      await _controller?.setGeoJsonSource('tap', _pointFeature(coordinates));
      if (!mounted) return;
    }
    final add = await showMapTapSheet(
      context: context,
      lat: coordinates.latitude,
      lng: coordinates.longitude,
      canPlace: _canPlace,
    );
    if (!mounted) return;
    if (!add) {
      if (_sourcesReady) {
        await _controller?.setGeoJsonSource('tap', _emptyFeatures());
      }
      return;
    }
    Navigator.of(context).pop(
      StagedPoint(lat: coordinates.latitude, lng: coordinates.longitude),
    );
  }

  Map<String, dynamic> _emptyFeatures() => {
    'type': 'FeatureCollection',
    'features': <dynamic>[],
  };

  Map<String, dynamic> _pointFeature(LatLng at) => {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [at.longitude, at.latitude],
        },
        'properties': <String, dynamic>{},
      },
    ],
  };

  /// Renders one pin image per hot-key (colour + icon) plus a neutral default,
  /// so the symbol layer can pick an image by the feature's `icon` property.
  Future<void> _ensurePinImages() async {
    final controller = _controller;
    if (controller == null) return;
    final hotKeys = await ref.read(databaseProvider).hotKeysFor(widget.groupId);
    _hotKeysById = {for (final h in hotKeys) h.id: h};
    for (final hotKey in hotKeys) {
      await controller.addImage(
        'pin_${hotKey.id}',
        await buildPinImage(
          color: Color(hotKey.colorValue),
          icon: hotKeyIcon(hotKey.iconName),
        ),
      );
    }
    await controller.addImage(
      'pin_default',
      await buildPinImage(color: const Color(0xFF15181B)),
    );
  }

  Future<void> _centerOnData(Map<String, dynamic> collection) async {
    final features = collection['features'] as List;
    if (features.isEmpty) return;
    final coordinates = [
      for (final feature in features)
        ((feature as Map)['geometry'] as Map)['coordinates'] as List,
    ];
    final lngs = coordinates.map((c) => (c[0] as num).toDouble()).toList();
    final lats = coordinates.map((c) => (c[1] as num).toDouble()).toList();
    final minLat = lats.reduce(min);
    final maxLat = lats.reduce(max);
    final minLng = lngs.reduce(min);
    final maxLng = lngs.reduce(max);

    if (maxLat - minLat < 0.002 && maxLng - minLng < 0.002) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          16,
        ),
      );
      return;
    }
    await _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 60,
        right: 60,
        top: 140,
        bottom: 60,
      ),
    );
  }

  /// Centers on one point and opens its detail sheet. Returns false when the
  /// point is not on the map (unlocated or not in this group).
  Future<bool> _focusMessage(String messageId) async {
    final index = _pointMessages.indexWhere((m) => m.id == messageId);
    if (index < 0) return false;
    final message = _pointMessages[index];
    if (message.lat == null || message.lng == null) return false;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(message.lat!, message.lng!), 17),
    );
    if (!mounted) return true;
    final tag = message.tagId == null ? null : _hotKeysById[message.tagId];
    unawaited(
      showPointSheet(
        context: context,
        message: message,
        tag: tag,
        mediaResolver: ref.read(databaseProvider).mediaBytes,
      ),
    );
    return true;
  }

  Future<void> _refreshPins() async {
    if (!_sourcesReady) return;
    await _ensurePinImages();
    await _controller?.setGeoJsonSource('points', await _featureCollection());
  }

  Future<Map<String, dynamic>> _featureCollection() async {
    final db = ref.read(databaseProvider);
    final messages = await db.messagesFor(widget.groupId);
    final hotKeys = await db.hotKeysFor(widget.groupId);
    final hotKeyIds = {for (final h in hotKeys) h.id};
    final byId = {for (final m in messages) m.id: m};

    final collection = buildFeatureCollection(messages, hotKeys);
    final features = collection['features'] as List;
    final ordered = <Message>[];
    for (var i = 0; i < features.length; i++) {
      final feature = features[i] as Map<String, dynamic>;
      feature['id'] = i;
      final properties = feature['properties'] as Map<String, dynamic>;
      final tagId = properties['tagId'] as String?;
      properties['icon'] = tagId != null && hotKeyIds.contains(tagId)
          ? 'pin_$tagId'
          : 'pin_default';
      ordered.add(byId[properties['id']]!);
    }
    _pointMessages = ordered;
    return collection;
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == 'clusters') {
      final zoom = (_controller?.cameraPosition?.zoom ?? 14) + 2;
      unawaited(
        _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(coordinates, zoom),
        ),
      );
      return;
    }
    if (layerId != 'points-symbols') return;
    final index = int.tryParse(id);
    if (index == null || index < 0 || index >= _pointMessages.length) return;
    final message = _pointMessages[index];
    final tag = message.tagId == null ? null : _hotKeysById[message.tagId];
    unawaited(
      showPointSheet(
        context: context,
        message: message,
        tag: tag,
        mediaResolver: ref.read(databaseProvider).mediaBytes,
      ),
    );
  }

  Future<Map<String, dynamic>> _trackLine() async {
    final points = await ref
        .read(databaseProvider)
        .trackSince(
          ref.read(currentUserIdProvider),
          DateTime.now().subtract(const Duration(hours: 24)),
        );
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          for (final p in points) [p.lng, p.lat],
        ],
      },
      'properties': <String, dynamic>{},
    };
  }
}

/// Circular map control that recenters the camera on the user's location.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.my_location, size: 22, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// Shown centered near the thumb when the user is outside the task area and it
/// has scrolled off screen: taps back to frame it.
class _ZoomToAreaPill extends StatelessWidget {
  const _ZoomToAreaPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.crop_free, size: 18, color: AppColors.amber),
              SizedBox(width: 8),
              Text(
                'Zoom to task area',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.groupName,
    required this.satellite,
    required this.onToggleBasemap,
  });

  final String groupName;
  final bool satellite;
  final VoidCallback onToggleBasemap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Row(
                  children: [
                    Icon(Icons.chevron_left, size: 18, color: AppColors.ink),
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            InkWell(
              onTap: onToggleBasemap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  satellite ? Icons.map_outlined : Icons.satellite_alt_outlined,
                  size: 20,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
