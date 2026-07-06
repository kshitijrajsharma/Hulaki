import 'dart:convert';

import 'package:fieldchat/features/export/geojson.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// A small non-interactive map that frames a group's drawn area, shown in the
/// public preview so a joiner sees where the group maps before joining.
class AreaMiniMap extends StatefulWidget {
  const AreaMiniMap({required this.aoiGeoJson, super.key});

  final String aoiGeoJson;

  @override
  State<AreaMiniMap> createState() => _AreaMiniMapState();
}

class _AreaMiniMapState extends State<AreaMiniMap> {
  static const _styleUrl =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  MapLibreMapController? _controller;

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.addGeoJsonSource(
      'aoi',
      jsonDecode(widget.aoiGeoJson) as Map<String, dynamic>,
    );
    await controller.addFillLayer(
      'aoi',
      'aoi-fill',
      const FillLayerProperties(fillColor: '#E0922A', fillOpacity: 0.15),
    );
    await controller.addLineLayer(
      'aoi',
      'aoi-line',
      const LineLayerProperties(lineColor: '#E0922A', lineWidth: 2),
    );
    final bounds = aoiBounds(widget.aoiGeoJson);
    if (bounds == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds[1], bounds[0]),
          northeast: LatLng(bounds[3], bounds[2]),
        ),
        left: 24,
        right: 24,
        top: 24,
        bottom: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: MapLibreMap(
        styleString: _styleUrl,
        initialCameraPosition: const CameraPosition(
          target: LatLng(27.7051, 85.3051),
          zoom: 12,
        ),
        onMapCreated: (controller) => _controller = controller,
        onStyleLoadedCallback: _onStyleLoaded,
      ),
    );
  }
}
