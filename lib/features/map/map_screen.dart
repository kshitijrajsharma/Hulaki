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
    this.backLabel = 'Chat',
    super.key,
  });

  final String groupId;
  final String groupName;

  /// Label on the back control, so the map reads correctly whether it was
  /// opened from a chat or from the Map tab.
  final String backLabel;

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
        // Esri imagery stops at ~z19; cap the source so MapLibre overzooms
        // (stretches) the last tiles instead of showing blank ones past it.
        'maxzoom': 19,
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
  bool _paintedOnce = false;
  bool _pointsSettled = false;
  bool _satellite = false;
  final Set<String> _pinImageKeys = {};
  String? _aoiGeoJson;
  bool _canPlace = true;
  bool _dataInView = true;
  LatLng? _lastLocation;
  bool _pendingInitialCenter = false;
  List<Message> _pointMessages = const [];
  Map<String, HotKey> _hotKeysById = const {};
  List<_LegendEntry> _legend = const [];
  final Set<String> _hiddenTags = {};
  bool _mineOnly = false;

  static const _othersKey = '__others__';

  @override
  void initState() {
    super.initState();
    unawaited(_startTracking());
    // Failsafe: never leave the loading chip up if the style load stalls.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 6)).then((_) {
        if (mounted && !_pointsSettled) {
          setState(() => _pointsSettled = true);
        }
      }),
    );
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

  /// Records the latest fix for the recenter button. Fed by both the position
  /// stream and the map's own location puck, so it holds whichever reports
  /// first.
  void _updateLocation(double lat, double lng) {
    _lastLocation = LatLng(lat, lng);
    // The first fix after opening recenters on the user, so the map lands where
    // you are standing even when no location was ready at style-load time.
    if (_pendingInitialCenter) {
      _pendingInitialCenter = false;
      unawaited(
        _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.5),
        ),
      );
    }
  }

  /// Tracks whether the data to frame (the mapping area, else the points) is
  /// within the viewport, so the "zoom" prompt hides once it is on screen.
  Future<void> _onCameraIdle() async {
    final controller = _controller;
    if (controller == null) return;
    // The first paint after a style load does not always draw the symbols on
    // iOS until the map redraws. The camera settling is that first redraw, so
    // push the points once more here.
    if (_sourcesReady && !_paintedOnce) {
      _paintedOnce = true;
      await _refreshPins();
    }
    final bounds = _dataBounds();
    final view = await controller.getVisibleRegion();
    final inView = bounds == null || _boundsIntersect(view, bounds);
    if (inView != _dataInView && mounted) {
      setState(() => _dataInView = inView);
    }
  }

  /// The box to frame: the mapping area if the group has one, else the extent
  /// of the points on the map. Null when there is neither.
  List<double>? _dataBounds() {
    final aoi = _aoiGeoJson;
    if (aoi != null) return aoiBounds(aoi);
    var minLng = 180.0;
    var minLat = 90.0;
    var maxLng = -180.0;
    var maxLat = -90.0;
    var any = false;
    for (final m in _pointMessages) {
      final lat = m.lat;
      final lng = m.lng;
      if (lat == null || lng == null) continue;
      any = true;
      if (lng < minLng) minLng = lng;
      if (lat < minLat) minLat = lat;
      if (lng > maxLng) maxLng = lng;
      if (lat > maxLat) maxLat = lat;
    }
    return any ? [minLng, minLat, maxLng, maxLat] : null;
  }

  /// Whether the box [minLng, minLat, maxLng, maxLat] overlaps [view].
  bool _boundsIntersect(LatLngBounds view, List<double> box) {
    return !(box[2] < view.southwest.longitude ||
        box[0] > view.northeast.longitude ||
        box[3] < view.southwest.latitude ||
        box[1] > view.northeast.latitude);
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

    // The legend sits in its own SafeArea, so its top edge is the bottom inset
    // plus its bar height. Offsetting the zoom pill by the same inset keeps it
    // clear of the legend on devices with a home indicator, iOS included.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _satellite
                ? MapScreen._satelliteStyle
                : MapScreen._osmStyle,
            // A neutral world view as a placeholder only: the style-load
            // callback snaps to the task area, points, or the user at once, so
            // this is never a real place the map appears to open on.
            initialCameraPosition: const CameraPosition(
              target: LatLng(20, 0),
              zoom: 1,
            ),
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.compass,
            // Drop the rotation compass below the header and GPS strip so the
            // top bars never cover it.
            compassViewPosition: CompassViewPosition.topRight,
            compassViewMargins: const Point(16, 176),
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
          if (!_pointsSettled)
            const Positioned.fill(
              child: IgnorePointer(child: Center(child: _MapLoadingChip())),
            ),
          Positioned(
            right: 16,
            bottom: 100,
            child: _RecenterButton(onTap: () => unawaited(_recenter())),
          ),
          Positioned(
            left: 16,
            bottom: 100,
            child: _BasemapToggle(
              satellite: _satellite,
              onTap: _toggleBasemap,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _MapHeader(
                    groupName: widget.groupName,
                    backLabel: widget.backLabel,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(11),
                          elevation: 2,
                          child: const LiveGpsStrip(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MineAllToggle(
                        mineOnly: _mineOnly,
                        onChanged: _setMineOnly,
                      ),
                    ],
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
          if (!_dataInView)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + (_legend.isEmpty ? 24 : 70),
              child: Center(
                child: _ZoomToAreaPill(
                  label: _aoiGeoJson != null
                      ? 'Zoom to mapping area'
                      : 'Zoom to points',
                  onTap: () => unawaited(_frameData()),
                ),
              ),
            ),
          if (_legend.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _LegendBar(
                entries: _legend,
                hidden: _hiddenTags,
                onToggle: (key) => unawaited(_toggleTag(key)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleBasemap() async {
    _sourcesReady = false;
    _paintedOnce = false;
    // A style reload drops the registered images, so let them be re-added.
    _pinImageKeys.clear();
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
        // Cluster only at overview zooms; from street level up (zoom > 14)
        // points show individually, so mapping your own points never leaves
        // them merged into one bubble. A tighter radius separates them sooner.
        clusterMaxZoom: 14,
        clusterRadius: 45,
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
    // Beneath the pins: a faded cone for points that carry a heading, rotated
    // to that bearing so it fans out from the point in the direction faced. The
    // pin and its icon are unchanged; this only adds the direction.
    await controller.addSymbolLayer(
      'points',
      'points-heading',
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'cone'],
        iconSize: 1,
        iconAnchor: 'bottom',
        iconRotate: [Expressions.get, 'heading'],
        iconRotationAlignment: 'map',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        'all',
        [
          '!',
          ['has', 'point_count'],
        ],
        ['has', 'heading'],
      ],
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
    // Seeding the source inline at add time does not always paint the pins on
    // the first frame, so push the collection once more now that the layers
    // and pin images exist, then a couple more times to force the symbol paint
    // iOS otherwise defers until a gesture.
    await _refreshPins();
    unawaited(_settlePins());

    // Framing and the focused-point sheet belong to the first load only. A
    // basemap toggle reloads the style and must not reopen the sheet or move
    // the camera the user just positioned.
    if (_styledOnce) return;
    _styledOnce = true;

    final focusId = widget.focusMessageId;
    if (focusId != null && await _focusMessage(focusId)) return;

    // On first open, frame the task area first so a stray far point cannot
    // zoom the map out, then the points, then the user. The recenter button
    // jumps back to your location. Animated so the frame reliably applies on
    // iOS, where an instant move right after style load can be dropped.
    if (_aoiGeoJson != null) {
      await _frameAoi();
      return;
    }
    if ((collection['features'] as List).isNotEmpty) {
      await _centerOnData(collection);
      return;
    }
    final me = _lastLocation;
    if (me != null) {
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(me, 16.5));
      return;
    }
    _pendingInitialCenter = true;
    unawaited(_seekInitialLocation());
  }

  /// Looks up a location off the map's own updates, so a device that is slow to
  /// stream a fix (common on iOS first open) still recenters. Uses the cached
  /// fix first, then a time-bounded lookup; the result recenters only while an
  /// initial center is still pending.
  Future<void> _seekInitialLocation() async {
    if (!await ensureLocationPermission()) return;
    var target = _lastLocation;
    if (target == null) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) target = LatLng(last.latitude, last.longitude);
    }
    if (target == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 8),
          ),
        );
        target = LatLng(pos.latitude, pos.longitude);
      } on TimeoutException {
        return;
      }
    }
    if (!_pendingInitialCenter || !mounted) return;
    _pendingInitialCenter = false;
    _lastLocation = target;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16.5),
    );
  }

  /// Frames the group's mapping area, if it has one.
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

  /// Frames the mapping area if the group has one, else the extent of the
  /// points on the map. Backs the "zoom" prompt when data is off screen.
  Future<void> _frameData() async {
    if (_aoiGeoJson != null) {
      await _frameAoi();
      return;
    }
    final bounds = _dataBounds();
    final controller = _controller;
    if (bounds == null || controller == null) return;
    if (bounds[2] - bounds[0] < 0.002 && bounds[3] - bounds[1] < 0.002) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((bounds[1] + bounds[3]) / 2, (bounds[0] + bounds[2]) / 2),
          16,
        ),
      );
      return;
    }
    await controller.animateCamera(
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
    // Add each image once per style load. Re-adding an existing image on every
    // refresh is wasteful and can stall the native side on iOS, which left the
    // pins unpainted and the loading chip stuck.
    for (final hotKey in hotKeys) {
      final color = Color(hotKey.colorValue);
      if (_pinImageKeys.add('pin_${hotKey.id}')) {
        await controller.addImage(
          'pin_${hotKey.id}',
          await buildPinImage(color: color, icon: hotKeyIcon(hotKey.iconName)),
        );
      }
      if (_pinImageKeys.add('cone_${hotKey.id}')) {
        await controller.addImage(
          'cone_${hotKey.id}',
          await buildHeadingConeImage(color: color),
        );
      }
    }
    if (_pinImageKeys.add('pin_default')) {
      await controller.addImage(
        'pin_default',
        await buildPinImage(color: const Color(0xFF15181B)),
      );
    }
    if (_pinImageKeys.add('cone_default')) {
      await controller.addImage(
        'cone_default',
        await buildHeadingConeImage(color: const Color(0xFF15181B)),
      );
    }
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
    if (mounted && !_pointsSettled) setState(() => _pointsSettled = true);
  }

  /// Re-pushes the points a few times over the first second after a style load.
  /// Each push forces a redraw, so the pins appear even on iOS, which otherwise
  /// leaves symbols unpainted until the map is touched.
  Future<void> _settlePins() async {
    for (final delayMs in const [200, 500, 900]) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (!mounted || _controller == null || !_sourcesReady) return;
      await _refreshPins();
    }
  }

  /// Switches the map between everyone's points and only the current user's.
  void _setMineOnly(bool value) {
    if (value == _mineOnly) return;
    setState(() => _mineOnly = value);
    unawaited(_refreshPins());
  }

  /// Shows or hides a tag's points on the map from the legend.
  Future<void> _toggleTag(String key) async {
    setState(() {
      if (!_hiddenTags.remove(key)) _hiddenTags.add(key);
    });
    await _refreshPins();
  }

  Future<Map<String, dynamic>> _featureCollection() async {
    final db = ref.read(databaseProvider);
    final all = await db.messagesFor(widget.groupId);
    // The Mine/All switch filters the map (and its legend counts) by author.
    final selfId = ref.read(currentUserIdProvider);
    final messages = _mineOnly
        ? [for (final m in all) if (m.senderId == selfId) m]
        : all;
    final hotKeys = await db.hotKeysFor(widget.groupId);
    final hotKeyIds = {for (final h in hotKeys) h.id};

    String keyFor(Message m) {
      final tag = m.tagId;
      return tag != null && hotKeyIds.contains(tag) ? tag : _othersKey;
    }

    // Live per-tag counts over located points, plus an "Others" bucket for
    // untagged ones, feeding the map legend.
    final counts = <String, int>{};
    for (final m in messages) {
      if (m.lat == null || m.lng == null || m.deletedAt != null) continue;
      counts.update(keyFor(m), (v) => v + 1, ifAbsent: () => 1);
    }
    final legend = <_LegendEntry>[
      for (final h in hotKeys)
        if ((counts[h.id] ?? 0) > 0)
          _LegendEntry(
            tagKey: h.id,
            label: h.label,
            color: Color(h.colorValue),
            count: counts[h.id]!,
          ),
      if ((counts[_othersKey] ?? 0) > 0)
        _LegendEntry(
          tagKey: _othersKey,
          label: 'Others',
          color: AppColors.textMuted,
          count: counts[_othersKey]!,
        ),
    ];
    if (mounted) setState(() => _legend = legend);

    // Drop points whose tag the user has toggled off.
    final visible = [
      for (final m in messages)
        if (!(m.lat != null &&
            m.lng != null &&
            m.deletedAt == null &&
            _hiddenTags.contains(keyFor(m))))
          m,
    ];
    final byId = {for (final m in visible) m.id: m};

    final collection = buildFeatureCollection(visible, hotKeys);
    final features = collection['features'] as List;
    final ordered = <Message>[];
    for (var i = 0; i < features.length; i++) {
      final feature = features[i] as Map<String, dynamic>;
      feature['id'] = i;
      final properties = feature['properties'] as Map<String, dynamic>;
      final message = byId[properties['id']]!;
      final tagId = properties['tagId'] as String?;
      final suffix = tagId != null && hotKeyIds.contains(tagId)
          ? tagId
          : 'default';
      properties['icon'] = 'pin_$suffix';
      final heading = message.headingDeg;
      if (heading != null) {
        properties['heading'] = heading;
        properties['cone'] = 'cone_$suffix';
      }
      ordered.add(message);
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
    if (layerId == 'aoi-fill') {
      unawaited(_onMapTapped(coordinates));
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

/// A small centred chip shown over the map while the points are loading in, so
/// an empty-looking map reads as loading rather than broken.
class _MapLoadingChip extends StatelessWidget {
  const _MapLoadingChip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 3,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.amber,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Loading points…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact segmented switch to filter the map between everyone's points and
/// only the current user's.
class _MineAllToggle extends StatelessWidget {
  const _MineAllToggle({required this.mineOnly, required this.onChanged});

  final bool mineOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(11),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment('All', selected: !mineOnly, onTap: () => onChanged(false)),
            _segment('Mine', selected: mineOnly, onTap: () => onChanged(true)),
          ],
        ),
      ),
    );
  }

  Widget _segment(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
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

/// Shown centered near the thumb when the data to frame has scrolled off
/// screen: taps back to frame the mapping area or the points.
class _ZoomToAreaPill extends StatelessWidget {
  const _ZoomToAreaPill({required this.label, required this.onTap});

  final String label;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.crop_free, size: 18, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
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
  const _MapHeader({required this.groupName, required this.backLabel});

  final String groupName;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            // The group name is centred; the back affordance floats over the
            // left so a long name stays visually centred in the bar.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 88),
                child: Center(
                  child: Text(
                    groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chevron_left,
                        size: 20,
                        color: AppColors.ink,
                      ),
                      Text(
                        backLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry in the map legend: a quick tag (or the "Others" bucket) with its
/// colour and how many points carry it.
class _LegendEntry {
  const _LegendEntry({
    required this.tagKey,
    required this.label,
    required this.color,
    required this.count,
  });

  final String tagKey;
  final String label;
  final Color color;
  final int count;
}

/// A horizontal legend and filter at the bottom of the map: each quick tag with
/// its live count, tapped to show or hide those points. Everything shows by
/// default; deselecting a tag hides it and untagged points fall under "Others".
class _LegendBar extends StatelessWidget {
  const _LegendBar({
    required this.entries,
    required this.hidden,
    required this.onToggle,
  });

  final List<_LegendEntry> entries;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  // Past this many tags a "more" pill floats above the bar to open the full
  // list; the bar itself always stays scrollable.
  static const _maxInline = 6;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => b.count.compareTo(a.count));
    final showMore = sorted.length > _maxInline;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bar = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth - 24),
            child: Material(
              color: AppColors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(22),
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) =>
                      _chip(sorted[i], on: !hidden.contains(sorted[i].tagKey)),
                ),
              ),
            ),
          );
          return Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMore) ...[
                  _ExpandPill(
                    onTap: () => unawaited(_showAllTags(context, sorted)),
                  ),
                  const SizedBox(height: 6),
                ],
                bar,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAllTags(
    BuildContext context,
    List<_LegendEntry> all,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TagSheet(entries: all, hidden: hidden, onToggle: onToggle),
    );
  }

  Widget _chip(_LegendEntry entry, {required bool on}) {
    return InkWell(
      onTap: () => onToggle(entry.tagKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: on ? entry.color.withValues(alpha: 0.16) : AppColors.mist,
          border: Border.all(
            color: on
                ? entry.color.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? entry.color : AppColors.textFaint,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${entry.label} · ${entry.count}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: on ? AppColors.ink : AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small pill that floats above a crowded legend; opens the full tag list.
class _ExpandPill extends StatelessWidget {
  const _ExpandPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 3),
          child: Icon(
            Icons.keyboard_arrow_up,
            size: 20,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// The full tag list as a bottom drawer: every tag with its count and a
/// show/hide toggle that filters the map live.
class _TagSheet extends StatefulWidget {
  const _TagSheet({
    required this.entries,
    required this.hidden,
    required this.onToggle,
  });

  final List<_LegendEntry> entries;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  late final Set<String> _hidden = {...widget.hidden};

  void _toggle(String key) {
    setState(() {
      if (!_hidden.remove(key)) _hidden.add(key);
    });
    widget.onToggle(key);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tags',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [for (final entry in widget.entries) _row(entry)],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(_LegendEntry entry) {
    final on = !_hidden.contains(entry.tagKey);
    return ListTile(
      onTap: () => _toggle(entry.tagKey),
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? entry.color : AppColors.textFaint,
        ),
      ),
      title: Text(
        entry.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: on ? AppColors.ink : AppColors.textFaint,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.count}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: on ? AppColors.textSecondary : AppColors.textFaint,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            on ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 18,
            color: on ? AppColors.ink : AppColors.textFaint,
          ),
        ],
      ),
    );
  }
}

/// A Google-style basemap switch: a small tile previewing the mode you would
/// switch to (satellite while on the street map, and the street map while on
/// satellite), with a label.
class _BasemapToggle extends StatelessWidget {
  const _BasemapToggle({required this.satellite, required this.onTap});

  final bool satellite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final toSatellite = !satellite;
    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: AppColors.ink.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.mist),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 14, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                toSatellite ? Icons.satellite_alt : Icons.map_outlined,
                size: 18,
                color: AppColors.ink,
              ),
              const SizedBox(width: 7),
              Text(
                toSatellite ? 'Satellite' : 'Map',
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
