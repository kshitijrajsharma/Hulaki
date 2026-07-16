import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/features/zones/domain/zone.dart';
import 'package:hulaki/features/zones/domain/zone_partition.dart';
import 'package:hulaki/features/zones/presentation/zone_seed_screen.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// The colours zones cycle through, shared with the tag palette so the map
/// stays visually coherent.
List<int> zoneColorPalette() => [
  for (final color in TagColors.palette) color.toARGB32(),
];

/// Admin hub for splitting the mapping area into zones and managing them. Only
/// reachable by an admin from group settings. Needs a mapping area first.
class ZoneManageScreen extends ConsumerWidget {
  const ZoneManageScreen({required this.groupId, super.key});

  final String groupId;

  Future<String?> _aoi(WidgetRef ref) async =>
      (await ref.read(databaseProvider).groupById(groupId))?.aoiGeoJson;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    List<Zone> zones,
    AppLocalizations l10n,
  ) async {
    if (zones.isEmpty) {
      _snack(context, l10n.zoneInvalidImport);
      return;
    }
    await ref.read(groupServiceProvider).setZones(groupId, zones);
    if (context.mounted) _snack(context, l10n.zoneSplitDone(zones.length));
  }

  Future<void> _splitEvenly(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final aoi = await _aoi(ref);
    if (aoi == null || !context.mounted) return;
    final count = await _askCount(context, l10n);
    if (count == null || !context.mounted) return;
    final zones = gridSplit(aoi, count, palette: zoneColorPalette());
    await _save(context, ref, zones, l10n);
  }

  Future<void> _splitBySeeds(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final aoi = await _aoi(ref);
    if (aoi == null || !context.mounted) return;
    final zones = await Navigator.of(context).push<List<Zone>>(
      MaterialPageRoute<List<Zone>>(
        builder: (_) => ZoneSeedScreen(aoiGeoJson: aoi),
      ),
    );
    if (zones == null || !context.mounted) return;
    await _save(context, ref, zones, l10n);
  }

  Future<void> _import(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final file = await openFile();
    if (file == null || !context.mounted) return;
    final text = utf8.decode(await file.readAsBytes());
    final zones = zonesFromImport(text, palette: zoneColorPalette());
    if (!context.mounted) return;
    await _save(context, ref, zones, l10n);
  }

  Future<void> _clear(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.zoneClear),
        content: Text(l10n.zoneClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.threadCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.zoneClear),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(groupServiceProvider).clearZones(groupId);
    }
  }

  Future<int?> _askCount(BuildContext context, AppLocalizations l10n) {
    var count = 4;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.zoneHowMany),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: count > 2 ? () => setState(() => count--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$count', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                onPressed: count < 8 ? () => setState(() => count++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.threadCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(count),
              child: Text(l10n.zoneSplitEvenly),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final zones = ref.watch(zonesProvider(groupId)).asData?.value ?? const [];
    final groups = ref.watch(activeGroupsProvider).asData?.value ?? const [];
    final match = groups.where((g) => g.id == groupId);
    final hasArea = match.isNotEmpty && match.first.aoiGeoJson != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.zoneManageTitle)),
      body: !hasArea
          ? _Message(text: l10n.zoneNeedArea)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.zoneManageSubtitle, style: theme(context).bodyMedium),
                const SizedBox(height: 16),
                _Action(
                  icon: Icons.grid_view_outlined,
                  title: l10n.zoneSplitEvenly,
                  detail: l10n.zoneSplitEvenlyDetail,
                  onTap: () => unawaited(_splitEvenly(context, ref, l10n)),
                ),
                _Action(
                  icon: Icons.place_outlined,
                  title: l10n.zoneSplitSeeds,
                  detail: l10n.zoneSplitSeedsDetail,
                  onTap: () => unawaited(_splitBySeeds(context, ref, l10n)),
                ),
                _Action(
                  icon: Icons.file_upload_outlined,
                  title: l10n.zoneImport,
                  detail: l10n.zoneImportDetail,
                  onTap: () => unawaited(_import(context, ref, l10n)),
                ),
                if (zones.isNotEmpty)
                  _Action(
                    icon: Icons.layers_clear_outlined,
                    title: l10n.zoneClear,
                    detail: l10n.zoneClearDetail,
                    danger: true,
                    onTap: () => unawaited(_clear(context, ref, l10n)),
                  ),
              ],
            ),
    );
  }

  TextTheme theme(BuildContext context) => Theme.of(context).textTheme;
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.ink;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(detail),
      onTap: onTap,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
