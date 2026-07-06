import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fieldchat/core/geo.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/features/capture/location_permission.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart' show Geolocator, LocationSettings;
import 'package:maplibre_gl/maplibre_gl.dart';

/// Draw a mapping area by tapping the map to drop polygon corners. Returns the
/// area as a GeoJSON string, or null if skipped.
class AreaDrawScreen extends StatefulWidget {
  const AreaDrawScreen({super.key});

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapping area'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import GeoJSON',
            onPressed: _importGeoJson,
          ),
          if (_points.isNotEmpty)
            TextButton(
              onPressed: _undo,
              child: const Text('Undo'),
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
            onStyleLoadedCallback: _onStyleLoaded,
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
                        decoration: const InputDecoration(
                          hintText: 'Search a place',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _search(),
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
              onPressed: _locating ? null : _goToMyLocation,
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
                    _points.length < 3
                        ? 'Tap the map to drop at least 3 corners.'
                        : '${_points.length} corners. Tap to add more.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _points.length >= 3 ? _use : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Use this area'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
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
    unawaited(_goToMyLocation(initial: true));
  }

  /// Centers the map on the device's location. On open it only nudges the
  /// starting view; the recenter button jumps closer.
  Future<void> _goToMyLocation({bool initial = false}) async {
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
          const SnackBar(content: Text('Could not get your location')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Moves the camera to the first geocoding match for the typed place.
  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final results = await geo.Geocoding().locationFromAddress(query);
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No place found for that search')),
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
          const SnackBar(content: Text('Place search is unavailable here')),
        );
      }
    }
  }

  Future<void> _onTap(Point<double> point, LatLng latLng) async {
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

  void _use() {
    if (_areaSqMeters() < _minAreaSqMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Area is too small. Draw a larger shape.'),
        ),
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
  Future<void> _importGeoJson() async {
    // No type filter: Android resolves .geojson to octet-stream, so filtering
    // by MIME hides valid files. The content is validated below instead.
    final file = await openFile();
    if (file == null) return;
    final text = utf8.decode(await file.readAsBytes());

    if (aoiBounds(text) == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That is not a valid GeoJSON area')),
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
