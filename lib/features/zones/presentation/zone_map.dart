import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hulaki/features/export/geojson.dart';
import 'package:hulaki/features/zones/domain/zone.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// A read-only map of zones: coloured outlines with names. A selected zone is
/// drawn in ink and framed. With no zones it falls back to the boundary, so the
/// current split stays legible.
class ZoneMap extends StatefulWidget {
  const ZoneMap({
    required this.zones,
    this.aoiGeoJson,
    this.selectedZoneId,
    super.key,
  });

  final List<Zone> zones;
  final String? aoiGeoJson;
  final String? selectedZoneId;

  static const _styleUrl =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  @override
  State<ZoneMap> createState() => _ZoneMapState();
}

class _ZoneMapState extends State<ZoneMap> {
  MapLibreMapController? _controller;

  @override
  void didUpdateWidget(ZoneMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reframe = oldWidget.selectedZoneId != widget.selectedZoneId;
    unawaited(_apply(reframe: reframe));
  }

  Future<void> _apply({required bool reframe}) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setGeoJsonSource('zones', _zoneFeatures());
    if (reframe) await _frame();
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: ZoneMap._styleUrl,
      initialCameraPosition: const CameraPosition(
        target: LatLng(27.7051, 85.3051),
        zoom: 12,
      ),
      onMapCreated: (controller) => _controller = controller,
      onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
    );
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    final aoi = widget.aoiGeoJson;
    if (aoi != null) {
      await controller.addGeoJsonSource(
        'aoi',
        jsonDecode(aoi) as Map<String, dynamic>,
      );
      await controller.addLineLayer(
        'aoi',
        'aoi-outline',
        const LineLayerProperties(lineColor: '#E0922A', lineWidth: 1.5),
      );
    }
    await controller.addGeoJsonSource('zones', _zoneFeatures());
    await controller.addLineLayer(
      'zones',
      'zones-outline',
      const LineLayerProperties(
        lineColor: [Expressions.get, 'lineColor'],
        lineWidth: [Expressions.get, 'lineWidth'],
      ),
    );
    await controller.addSymbolLayer(
      'zones',
      'zones-label',
      const SymbolLayerProperties(
        textField: [Expressions.get, 'name'],
        textSize: 12,
        textColor: '#15181B',
        textHaloColor: '#F6F6F4',
        textHaloWidth: 1.4,
        textFont: ['Open Sans Semibold'],
        symbolPlacement: 'point',
      ),
    );
    await _frame();
  }

  Future<void> _frame() async {
    final controller = _controller;
    if (controller == null) return;
    final bounds =
        _boundsForZone(widget.selectedZoneId) ??
        _aoiBounds() ??
        _boundsForZone(null);
    if (bounds == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 32,
        right: 32,
        top: 32,
        bottom: 32,
      ),
    );
  }

  Map<String, dynamic> _zoneFeatures() => {
    'type': 'FeatureCollection',
    'features': [
      for (final zone in widget.zones)
        {
          'type': 'Feature',
          'properties': {
            'name': zone.name,
            'lineColor': zone.id == widget.selectedZoneId
                ? '#15181B'
                : _hex(zone.colorValue),
            'lineWidth': zone.id == widget.selectedZoneId ? 3.0 : 1.8,
          },
          'geometry': {
            'type': 'MultiPolygon',
            'coordinates': [
              for (final ring in zone.pieces) [ring],
            ],
          },
        },
    ],
  };

  String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  LatLngBounds? _aoiBounds() {
    final aoi = widget.aoiGeoJson;
    if (aoi == null) return null;
    final box = aoiBounds(aoi);
    if (box == null) return null;
    return LatLngBounds(
      southwest: LatLng(box[1], box[0]),
      northeast: LatLng(box[3], box[2]),
    );
  }

  /// Bounds of one zone, or of every zone when [zoneId] is null.
  LatLngBounds? _boundsForZone(String? zoneId) {
    var minLng = 180.0;
    var minLat = 90.0;
    var maxLng = -180.0;
    var maxLat = -90.0;
    var any = false;
    for (final zone in widget.zones) {
      if (zoneId != null && zone.id != zoneId) continue;
      for (final ring in zone.pieces) {
        for (final point in ring) {
          any = true;
          minLng = point[0] < minLng ? point[0] : minLng;
          maxLng = point[0] > maxLng ? point[0] : maxLng;
          minLat = point[1] < minLat ? point[1] : minLat;
          maxLat = point[1] > maxLat ? point[1] : maxLat;
        }
      }
    }
    if (!any) return null;
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
