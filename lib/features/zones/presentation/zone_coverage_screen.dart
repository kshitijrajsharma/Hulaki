import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/features/zones/domain/zone.dart';
import 'package:hulaki/features/zones/domain/zone_bucketing.dart';
import 'package:hulaki/l10n/app_localizations.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Admin-only coverage: a map of the zones over the list, so which area is
/// which is clear. Tapping a zone expands its full mapper list and highlights
/// it on the map. Names show only here (like the hidden roster); anonymous
/// points count but stay unnamed.
class ZoneCoverageScreen extends ConsumerStatefulWidget {
  const ZoneCoverageScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<ZoneCoverageScreen> createState() => _ZoneCoverageScreenState();
}

class _ZoneCoverageScreenState extends ConsumerState<ZoneCoverageScreen> {
  String? _selectedZoneId;

  Future<void> _rename(String zoneId, String currentName) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zoneRenameTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.threadCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.threadSave),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final all =
        ref.read(zonesProvider(widget.groupId)).asData?.value ?? const [];
    final updated = [
      for (final zone in all)
        if (zone.id == zoneId) zone.copyWith(name: name) else zone,
    ];
    await ref.read(groupServiceProvider).setZones(widget.groupId, updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final zones =
        ref.watch(zonesProvider(widget.groupId)).asData?.value ?? const [];
    final members =
        ref.watch(groupMembersProvider(widget.groupId)).asData?.value ??
        const [];
    final messages =
        ref.watch(messagesProvider(widget.groupId)).asData?.value ?? const [];

    final counts = countsByZone(zones, [
      for (final m in messages)
        if (m.lat != null && m.lng != null) (lat: m.lat!, lng: m.lng!),
    ]);
    final total = counts.values.fold(0, (a, b) => a + b);

    final ordered = [...zones]
      ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(l10n.zoneCoverageTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (zones.isNotEmpty)
            _CoverageMap(zones: zones, selectedZoneId: _selectedZoneId),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.zoneCoverageSummary(total, zones.length),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.zoneCoverageExplain,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final zone in ordered)
                  _CoverageRow(
                    name: zone.name,
                    colorValue: zone.colorValue,
                    points: counts[zone.id] ?? 0,
                    mappers: [
                      for (final m in members)
                        if (m.assignedZoneId == zone.id) m.name,
                    ],
                    expanded: _selectedZoneId == zone.id,
                    onTap: () => setState(
                      () => _selectedZoneId = _selectedZoneId == zone.id
                          ? null
                          : zone.id,
                    ),
                    onRename: () => unawaited(_rename(zone.id, zone.name)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A framed, read-only map of the zones (coloured outlines with names). The
/// selected zone is drawn in ink and the camera frames it.
class _CoverageMap extends StatefulWidget {
  const _CoverageMap({required this.zones, required this.selectedZoneId});

  final List<Zone> zones;
  final String? selectedZoneId;

  static const _styleUrl =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  @override
  State<_CoverageMap> createState() => _CoverageMapState();
}

class _CoverageMapState extends State<_CoverageMap> {
  MapLibreMapController? _controller;

  @override
  void didUpdateWidget(_CoverageMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedZoneId != widget.selectedZoneId) {
      unawaited(_apply());
    }
  }

  Future<void> _apply() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setGeoJsonSource('zones', _features());
    final bounds = _boundsFor(widget.selectedZoneId) ?? _boundsFor(null);
    if (bounds != null) {
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
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: MapLibreMap(
        styleString: _CoverageMap._styleUrl,
        initialCameraPosition: const CameraPosition(
          target: LatLng(27.7051, 85.3051),
          zoom: 12,
        ),
        onMapCreated: (controller) => _controller = controller,
        onStyleLoadedCallback: _onStyleLoaded,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.addGeoJsonSource('zones', _features());
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
        textHaloColor: '#F6F4EE',
        textHaloWidth: 1.4,
        textFont: ['Open Sans Semibold'],
        symbolPlacement: 'point',
      ),
    );
    final bounds = _boundsFor(widget.selectedZoneId) ?? _boundsFor(null);
    if (bounds != null) {
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
  }

  Map<String, dynamic> _features() => {
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

  /// Bounds of one zone, or of every zone when [zoneId] is null.
  LatLngBounds? _boundsFor(String? zoneId) {
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

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.name,
    required this.colorValue,
    required this.points,
    required this.mappers,
    required this.expanded,
    required this.onTap,
    required this.onRename,
  });

  final String name;
  final int colorValue;
  final int points;
  final List<String> mappers;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onRename;

  /// Two names then a count when collapsed; the whole team when expanded.
  String _mappersLabel(AppLocalizations l10n) {
    if (mappers.isEmpty) return l10n.zoneNeedsMapper;
    if (expanded || mappers.length <= 2) return mappers.join(', ');
    return '${mappers.take(2).join(', ')} +${mappers.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      selected: expanded,
      selectedTileColor: AppColors.mist,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Color(colorValue),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(name, style: theme.titleMedium)),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRename,
            borderRadius: BorderRadius.circular(99),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        _mappersLabel(l10n),
        maxLines: expanded ? null : 1,
        overflow: expanded ? null : TextOverflow.ellipsis,
        style: theme.bodySmall?.copyWith(
          color: mappers.isEmpty
              ? AppColors.amberText
              : AppColors.textSecondary,
          fontWeight: mappers.isEmpty ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      trailing: Text('$points', style: theme.titleLarge),
    );
  }
}
