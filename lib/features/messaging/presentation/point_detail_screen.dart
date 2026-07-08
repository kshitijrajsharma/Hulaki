import 'dart:async';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/core/time_format.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/groups/group_member_view.dart';
import 'package:fieldchat/features/groups/hot_key_icons.dart';
import 'package:fieldchat/features/map/map_screen.dart';
import 'package:fieldchat/features/map/navigate_sheet.dart';
import 'package:fieldchat/features/settings/units.dart';
import 'package:fieldchat/features/settings/units_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide buildFeatureCollection;

typedef MediaResolver = Future<Uint8List?> Function(String mediaId);

/// A single observation in full: its photo, who sent it, when, and the location
/// with accuracy, over a mini-map that shows it among the group's other points.
class PointDetailScreen extends ConsumerStatefulWidget {
  const PointDetailScreen({
    required this.groupId,
    required this.message,
    this.tagLabel,
    this.tagColor,
    this.tagIcon,
    this.mediaResolver,
    super.key,
  });

  final String groupId;
  final Message message;
  final String? tagLabel;
  final Color? tagColor;
  final String? tagIcon;
  final MediaResolver? mediaResolver;

  static const _styleUrl =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

  @override
  ConsumerState<PointDetailScreen> createState() => _PointDetailScreenState();
}

class _PointDetailScreenState extends ConsumerState<PointDetailScreen> {
  MapLibreMapController? _controller;

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    final message = widget.message;
    if (controller == null || message.lat == null || message.lng == null) {
      return;
    }
    final db = ref.read(databaseProvider);
    final messages = await db.messagesFor(widget.groupId);
    final hotKeys = await db.hotKeysFor(widget.groupId);
    final colors = {for (final h in hotKeys) h.id: _hex(h.colorValue)};

    final collection = buildFeatureCollection(messages, hotKeys);
    for (final feature in collection['features'] as List) {
      final properties = (feature as Map)['properties'] as Map<String, dynamic>;
      properties['color'] = colors[properties['tagId']] ?? _hex(0xFF8C887F);
      properties['self'] = properties['id'] == message.id ? 1.0 : 0.6;
    }

    await controller.addGeoJsonSource('points', collection);
    await controller.addCircleLayer(
      'points',
      'points-circles',
      const CircleLayerProperties(
        circleColor: [Expressions.get, 'color'],
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.get, 'self'],
          0.6,
          5,
          1.0,
          9,
        ],
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2,
      ),
    );
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(message.lat!, message.lng!), 16),
    );
  }

  Future<void> _openFullMap() async {
    final group = await ref.read(databaseProvider).groupById(widget.groupId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          groupId: widget.groupId,
          groupName: group?.name ?? 'Map',
          focusMessageId: widget.message.id,
        ),
      ),
    );
  }

  Future<void> _navigate() async {
    final message = widget.message;
    await showNavigateSheet(
      context: context,
      lat: message.lat!,
      lng: message.lng!,
      label: message.body,
    );
  }

  Future<void> _copyCoords() async {
    final message = widget.message;
    await Clipboard.setData(
      ClipboardData(text: '${message.lat}, ${message.lng}'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordinates copied')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this point?'),
        content: const Text('It is removed for everyone in the group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    final navigator = Navigator.of(context);
    final sync = ref.read(syncServiceProvider);
    navigator.pop();
    await sync.deleteMessage(widget.message.id);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final accuracy = message.accuracyM;
    final located = message.lat != null && message.lng != null;
    final glyph = hotKeyIcon(widget.tagIcon);
    final resolver = widget.mediaResolver;
    final names =
        ref.watch(profileNamesProvider).asData?.value ??
        const <String, String>{};
    final units = ref.watch(unitsProvider);
    final live = ref.watch(liveLocationProvider).asData?.value;
    final distanceM = (located && live != null)
        ? Geolocator.distanceBetween(
            live.lat,
            live.lng,
            message.lat!,
            message.lng!,
          )
        : null;
    final selfId = ref.watch(currentUserIdProvider);
    final members =
        ref.watch(groupMembersProvider(widget.groupId)).asData?.value ??
        const <GroupMemberView>[];
    final iAmAdmin = members.any((m) => m.profileId == selfId && m.isAdmin);
    final canDelete = message.senderId == selfId || iAmAdmin;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Point'),
        actions: [
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => unawaited(_confirmDelete()),
            ),
        ],
      ),
      body: ListView(
        children: [
          if (message.mediaId != null && resolver != null)
            FutureBuilder<Uint8List?>(
              future: resolver(message.mediaId!),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                return Container(
                  height: 220,
                  color: AppColors.mist,
                  alignment: Alignment.center,
                  child: bytes == null
                      ? const SizedBox.shrink()
                      : Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.tagLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.tagColor ?? AppColors.ink,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (glyph != null) ...[
                          Icon(glyph, size: 13, color: AppColors.white),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          widget.tagLabel!,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (message.body != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    message.body!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'by ${names[message.senderId] ?? 'Member'}',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (located)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: GestureDetector(
                      onTap: _openFullMap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 200,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: MapLibreMap(
                                    styleString: PointDetailScreen._styleUrl,
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        message.lat!,
                                        message.lng!,
                                      ),
                                      zoom: 16,
                                    ),
                                    onMapCreated: (c) => _controller = c,
                                    onStyleLoadedCallback: _onStyleLoaded,
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 8,
                                bottom: 8,
                                child: _OpenMapHint(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                InkWell(
                  onTap: located ? _copyCoords : null,
                  child: _MetaRow(
                    icon: Icons.location_on_outlined,
                    label: message.locationPending
                        ? 'Location pending'
                        : '${message.lat?.toStringAsFixed(5)}, '
                              '${message.lng?.toStringAsFixed(5)}',
                    trailing: accuracy != null
                        ? '±${accuracy.round()} m'
                        : (located ? 'Placed on map' : null),
                    action: located ? Icons.copy : null,
                  ),
                ),
                if (distanceM != null)
                  _MetaRow(
                    icon: Icons.straighten,
                    label: '${formatDistance(distanceM, units)} from you',
                  ),
                if (message.altitudeM != null)
                  _MetaRow(
                    icon: Icons.terrain,
                    label:
                        'Elevation '
                        '${formatElevation(message.altitudeM!, units)}',
                  ),
                if (message.headingDeg != null)
                  _HeadingRow(headingDeg: message.headingDeg!),
                const Divider(),
                _SentRow(when: message.createdAt),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Open in chat'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: located ? _navigate : null,
                        icon: const Icon(Icons.navigation_outlined, size: 16),
                        label: const Text('Navigate'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

class _OpenMapHint extends StatelessWidget {
  const _OpenMapHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 4),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_full, size: 13, color: AppColors.ink),
          SizedBox(width: 5),
          Text(
            'Open full map',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.action,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final IconData? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(action, size: 14, color: AppColors.textFaint),
            ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gpsStrong,
              ),
            ),
        ],
      ),
    );
  }
}

/// The facing direction recorded at capture, shown as a rotated arrow and an
/// eight-point cardinal with the raw bearing.
class _HeadingRow extends StatelessWidget {
  const _HeadingRow({required this.headingDeg});

  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Transform.rotate(
            angle: degreesToRadians(headingDeg),
            child: const Icon(
              Icons.navigation,
              size: 16,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Facing ${cardinalFor(headingDeg)} · ${headingDeg.round()}°',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// The send time as a relative label that reveals the exact local time on tap.
class _SentRow extends StatefulWidget {
  const _SentRow({required this.when});

  final DateTime when;

  @override
  State<_SentRow> createState() => _SentRowState();
}

class _SentRowState extends State<_SentRow> {
  bool _exact = false;

  @override
  Widget build(BuildContext context) {
    final label = _exact ? exactTime(widget.when) : relativePhrase(widget.when);
    return InkWell(
      onTap: () => setState(() => _exact = !_exact),
      child: _MetaRow(icon: Icons.schedule, label: 'Sent $label'),
    );
  }
}
