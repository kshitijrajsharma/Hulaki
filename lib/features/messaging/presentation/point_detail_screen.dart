import 'dart:async';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/core/time_format.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/gps_strip.dart';
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
  bool _editingNote = false;
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

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
          backLabel: 'Back',
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

  void _startNoteEdit(String initial) {
    _noteController.text = initial;
    setState(() => _editingNote = true);
  }

  void _cancelNoteEdit() => setState(() => _editingNote = false);

  Future<void> _saveNoteEdit(Message message) async {
    final text = _noteController.text.trim();
    setState(() => _editingNote = false);
    if (text.isEmpty || text == (message.body ?? '')) return;
    await ref
        .read(syncServiceProvider)
        .editMessage(messageId: message.id, newBody: text);
  }

  Future<void> _editTag(Message message, List<HotKey> hotKeys) async {
    final chosen = await showModalBottomSheet<_TagChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RetagSheet(hotKeys: hotKeys, selectedId: message.tagId),
    );
    if (chosen == null) return;
    await ref
        .read(syncServiceProvider)
        .setMessageTag(messageId: message.id, tagId: chosen.tagId);
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the point and its tag from the live streams so an edit made here
    // (text or tag) redraws this screen at once. Selecting just this message
    // keeps the mini-map from rebuilding when unrelated points sync in.
    final message = ref.watch(
      messagesProvider(widget.groupId).select((async) {
        final list = async.asData?.value;
        if (list != null) {
          for (final m in list) {
            if (m.id == widget.message.id) return m;
          }
        }
        return widget.message;
      }),
    );
    final hotKeys =
        ref.watch(hotKeysProvider(widget.groupId)).asData?.value ??
        const <HotKey>[];
    HotKey? tag;
    if (message.tagId != null) {
      for (final h in hotKeys) {
        if (h.id == message.tagId) {
          tag = h;
          break;
        }
      }
    }
    final tagLabel = tag?.label ?? widget.tagLabel;
    final tagColor = tag != null ? Color(tag.colorValue) : widget.tagColor;
    final glyph = hotKeyIcon(tag?.iconName ?? widget.tagIcon);

    final accuracy = message.accuracyM;
    final accuracyTier = accuracy == null ? null : gpsTierFor(accuracy);
    final located = message.lat != null && message.lng != null;
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
    final canEdit = message.senderId == selfId || iAmAdmin;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Point detail'),
        actions: [
          if (canEdit)
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
                if (tagLabel != null)
                  _TagChip(
                    label: tagLabel,
                    color: tagColor ?? AppColors.ink,
                    glyph: glyph,
                    onTap: canEdit
                        ? () => unawaited(_editTag(message, hotKeys))
                        : null,
                  )
                else if (canEdit)
                  _AddTagChip(
                    onTap: () => unawaited(_editTag(message, hotKeys)),
                  ),
                if (_editingNote)
                  _NoteEditor(
                    controller: _noteController,
                    focusNode: _noteFocus,
                    onCancel: _cancelNoteEdit,
                    onSave: () => unawaited(_saveNoteEdit(message)),
                  )
                else if (message.body != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _NoteTitle(
                    text: message.body!,
                    onTap: canEdit
                        ? () => _startNoteEdit(message.body!)
                        : null,
                  ),
                ] else if (canEdit) ...[
                  const SizedBox(height: AppSpacing.md),
                  _AddNote(onTap: () => _startNoteEdit('')),
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
                        ? '${accuracyTier!.label} · ±${accuracy.round()} m'
                        : (located ? 'Placed on map' : null),
                    trailingColor: accuracyTier?.color,
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
    this.trailingColor,
    this.action,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final Color? trailingColor;
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: trailingColor ?? AppColors.gpsStrong,
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

/// The point's note as a large title. When editable it is tappable to edit in
/// place, with a faint pencil to signal that.
class _NoteTitle extends StatelessWidget {
  const _NoteTitle({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = Text(text, style: Theme.of(context).textTheme.titleLarge);
    if (onTap == null) return title;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          const Padding(
            padding: EdgeInsets.only(left: 6, top: 4),
            child: Icon(
              Icons.edit_outlined,
              size: 15,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Edits a point's note in place. Its controller and focus are owned by the
/// screen state, so they outlive this widget's rebuilds.
class _NoteEditor extends StatelessWidget {
  const _NoteEditor({
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          maxLines: null,
          style: Theme.of(context).textTheme.titleLarge,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Describe this point',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(onPressed: onSave, child: const Text('Save')),
          ],
        ),
      ],
    );
  }
}

/// A tappable placeholder to add a note to a point you are allowed to edit.
class _AddNote extends StatelessWidget {
  const _AddNote({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 15, color: AppColors.textMuted),
          SizedBox(width: 4),
          Text(
            'Add note',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The point's tag as a coloured chip, tappable to re-tag when editable.
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.color,
    this.glyph,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData? glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                Icon(glyph, size: 13, color: AppColors.white),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
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

/// A dashed placeholder for tagging an untagged point you are allowed to edit.
class _AddTagChip extends StatelessWidget {
  const _AddTagChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.mist),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text(
              'Add tag',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picked tag returned from [_RetagSheet]; a null [tagId] clears the tag.
class _TagChoice {
  const _TagChoice(this.tagId);

  final String? tagId;
}

/// A drawer to change a point's tag: every quick tag plus a clear option.
class _RetagSheet extends StatelessWidget {
  const _RetagSheet({required this.hotKeys, required this.selectedId});

  final List<HotKey> hotKeys;
  final String? selectedId;

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
                  'Change tag',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final hotKey in hotKeys)
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(hotKey.colorValue),
                  child: Icon(
                    hotKeyIcon(hotKey.iconName) ?? Icons.label,
                    size: 14,
                    color: AppColors.white,
                  ),
                ),
                title: Text(hotKey.label),
                trailing: hotKey.id == selectedId
                    ? const Icon(Icons.check, color: AppColors.ink)
                    : null,
                onTap: () => Navigator.of(context).pop(_TagChoice(hotKey.id)),
              ),
            ListTile(
              leading: const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.mist,
                child: Icon(Icons.block, size: 14, color: AppColors.textMuted),
              ),
              title: const Text('No tag'),
              trailing: selectedId == null
                  ? const Icon(Icons.check, color: AppColors.ink)
                  : null,
              onTap: () => Navigator.of(context).pop(const _TagChoice(null)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
