import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart' show Geolocator, LocationSettings;
import 'package:hulaki/core/geo.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/features/capture/location_permission.dart';
import 'package:hulaki/features/export/geojson.dart';
import 'package:hulaki/l10n/app_localizations.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Draw a mapping area by tapping the map to drop polygon corners. Returns the
/// area as a GeoJSON string, or null if skipped.
class AreaDrawScreen extends StatefulWidget {
  const AreaDrawScreen({this.initialArea, super.key});

  /// The group's current mapping area, so editing opens on it (drawn and
  /// framed) rather than a blank canvas. Null when setting an area for the
  /// first time.
  final String? initialArea;

  static const _styleUrl =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  @override
  State<AreaDrawScreen> createState() => _AreaDrawScreenState();
}

class _AreaDrawScreenState extends State<AreaDrawScreen> {
  MapLibreMapController? _controller;
  final List<LatLng> _points = [];
  final _searchController = TextEditingController();
  bool _locating = false;
  bool _readOnlyArea = false;

  /// Above this many corners an area is treated as imported: shown read-only to
  /// clear or replace, since editing thousands of vertices by tapping is not
  /// feasible and would choke the map.
  static const _maxEditableVertices = 50;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupMappingAreaTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: l10n.groupImportGeoJson,
            onPressed: () => unawaited(_importGeoJson(l10n)),
          ),
          if (_points.isNotEmpty || _readOnlyArea)
            TextButton(
              onPressed: _clear,
              child: Text(l10n.groupClearArea),
            ),
          if (_points.isNotEmpty)
            TextButton(
              onPressed: _undo,
              child: Text(l10n.groupUndo),
            ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: AreaDrawScreen._styleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(27.7051, 85.3051),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.compass,
            onMapCreated: (controller) => _controller = controller,
            onStyleLoadedCallback: () => unawaited(_onStyleLoaded(l10n)),
            onMapClick: _onTap,
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: l10n.groupSearchPlaceHint,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => unawaited(_search(l10n)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 150,
            child: FloatingActionButton.small(
              heroTag: 'area-my-location',
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.ink,
              onPressed: _locating
                  ? null
                  : () => unawaited(_goToMyLocation(l10n)),
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    _readOnlyArea
                        ? l10n.groupAreaImportedHint
                        : _points.length < 3
                        ? l10n.groupAreaDrawHint
                        : l10n.groupAreaCornerCount(_points.length),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _points.length >= 3 ? () => _use(l10n) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.groupUseThisArea),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onStyleLoaded(AppLocalizations l10n) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.addGeoJsonSource('aoi-poly', _empty());
    await controller.addGeoJsonSource('aoi-verts', _empty());
    await controller.addFillLayer(
      'aoi-poly',
      'aoi-fill',
      const FillLayerProperties(fillColor: '#E0922A', fillOpacity: 0.15),
    );
    await controller.addLineLayer(
      'aoi-poly',
      'aoi-line',
      const LineLayerProperties(lineColor: '#E0922A', lineWidth: 2),
    );
    await controller.addCircleLayer(
      'aoi-verts',
      'aoi-verts',
      const CircleLayerProperties(
        circleColor: '#ffffff',
        circleStrokeColor: '#E0922A',
        circleStrokeWidth: 2,
        circleRadius: 5,
      ),
    );

    final area = widget.initialArea;
    if (area != null) {
      await _loadExistingArea(area);
      await _frameToArea(area);
      return;
    }
    unawaited(_goToMyLocation(l10n, initial: true));
  }

  /// Shows the group's current area on open. A hand-drawn area (few corners)
  /// becomes editable handles; a large imported boundary is shown read-only as
  /// a backdrop to clear or replace, so thousands of vertices never choke it.
  Future<void> _loadExistingArea(String area) async {
    final rings = polygonRings(area);
    if (rings.isEmpty) return;
    final ring = rings.first;
    final open =
        ring.length > 1 &&
            ring.first[0] == ring.last[0] &&
            ring.first[1] == ring.last[1]
        ? ring.sublist(0, ring.length - 1)
        : ring;
    if (open.length > _maxEditableVertices) {
      setState(() => _readOnlyArea = true);
      await _controller?.setGeoJsonSource(
        'aoi-poly',
        jsonDecode(area) as Map<String, dynamic>,
      );
      return;
    }
    setState(() {
      _points
        ..clear()
        ..addAll([for (final p in open) LatLng(p[1], p[0])]);
    });
    await _redraw();
  }

  Future<void> _frameToArea(String area) async {
    final bounds = aoiBounds(area);
    if (bounds == null) return;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds[1], bounds[0]),
          northeast: LatLng(bounds[3], bounds[2]),
        ),
        left: 40,
        right: 40,
        top: 80,
        bottom: 160,
      ),
    );
  }

  void _clear() {
    setState(() {
      _points.clear();
      _readOnlyArea = false;
    });
    unawaited(_redraw());
  }

  /// Centers the map on the device's location. On open it only nudges the
  /// starting view; the recenter button jumps closer.
  Future<void> _goToMyLocation(
    AppLocalizations l10n, {
    bool initial = false,
  }) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await ensureLocationPermission()) return;
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              timeLimit: Duration(seconds: 8),
            ),
          );
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          initial ? 15 : 16,
        ),
      );
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupLocationUnavailable)),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Moves the camera to the first geocoding match for the typed place.
  Future<void> _search(AppLocalizations l10n) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final results = await geo.Geocoding().locationFromAddress(query);
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupNoPlaceFound)),
        );
        return;
      }
      final place = results.first;
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(place.latitude, place.longitude),
          15,
        ),
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupPlaceSearchUnavailable)),
        );
      }
    }
  }

  Future<void> _onTap(Point<double> point, LatLng latLng) async {
    if (_readOnlyArea) return;
    setState(() => _points.add(latLng));
    await _redraw();
  }

  Future<void> _undo() async {
    if (_points.isEmpty) return;
    setState(_points.removeLast);
    await _redraw();
  }

  Future<void> _redraw() async {
    await _controller?.setGeoJsonSource('aoi-verts', _vertices());
    await _controller?.setGeoJsonSource('aoi-poly', _polygonFeature());
  }

  /// A drawn area smaller than this is almost always stray taps, so it is
  /// rejected rather than saved as a sliver polygon.
  static const _minAreaSqMeters = 100.0;

  void _use(AppLocalizations l10n) {
    if (_areaSqMeters() < _minAreaSqMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupAreaTooSmall)),
      );
      return;
    }
    Navigator.of(context).pop(jsonEncode(_polygonFeature()));
  }

  double _areaSqMeters() => ringAreaSqMeters(
    _points.map((p) => p.latitude).toList(),
    _points.map((p) => p.longitude).toList(),
  );

  /// Pick a .geojson/.json file and use it as the area. Validated by extracting
  /// its bounds (Feature/FeatureCollection/Polygon); a valid area is returned.
  Future<void> _importGeoJson(AppLocalizations l10n) async {
    // No type filter: Android resolves .geojson to octet-stream, so filtering
    // by MIME hides valid files. The content is validated below instead.
    final file = await openFile();
    if (file == null) return;
    final text = utf8.decode(await file.readAsBytes());

    if (aoiBounds(text) == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupInvalidGeoJson)),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(text);
  }

  Map<String, dynamic> _empty() => {
    'type': 'FeatureCollection',
    'features': <dynamic>[],
  };

  Map<String, dynamic> _vertices() => {
    'type': 'FeatureCollection',
    'features': [
      for (final p in _points)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [p.longitude, p.latitude],
          },
        },
    ],
  };

  Map<String, dynamic> _polygonFeature() {
    final ring = [
      for (final p in _points) [p.longitude, p.latitude],
    ];
    if (ring.length >= 3) ring.add(ring.first);
    return {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': {
        'type': _points.length >= 3 ? 'Polygon' : 'LineString',
        'coordinates': _points.length >= 3 ? [ring] : ring,
      },
    };
  }
}
