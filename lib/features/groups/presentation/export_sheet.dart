import 'dart:io';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/primary_button.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/export/gpx.dart';
import 'package:fieldchat/features/export/project_archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _Format { project, geojson, gpx }

/// Export the group's data: a self-contained project .zip, light GeoJSON, or a
/// GPX track and waypoints.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({required this.group, super.key});

  final Group group;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  _Format _format = _Format.project;
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      final messages = await db.messagesFor(widget.group.id);
      final hotKeys = await db.hotKeysFor(widget.group.id);
      final dir = await getTemporaryDirectory();
      final slug = widget.group.name.toLowerCase().replaceAll(
        RegExp('[^a-z0-9]+'),
        '-',
      );

      final track = await db.trackSince(
        ref.read(currentUserIdProvider),
        DateTime.now().subtract(const Duration(hours: 24)),
      );

      final XFile file;
      switch (_format) {
        case _Format.geojson:
          final path = '${dir.path}/$slug.geojson';
          await File(path).writeAsString(
            featureCollectionToString(
              buildFeatureCollection(messages, hotKeys),
            ),
          );
          file = XFile(path);
        case _Format.gpx:
          final path = '${dir.path}/$slug.gpx';
          await File(path).writeAsString(
            buildGpx(
              name: widget.group.name,
              messages: messages,
              hotKeys: hotKeys,
              track: track,
            ),
          );
          file = XFile(path);
        case _Format.project:
          final zip = await buildProjectArchive(
            group: widget.group,
            hotKeys: hotKeys,
            messages: messages,
            mediaResolver: db.mediaBytes,
            track: track,
            exportedAt: DateTime.now(),
          );
          final path = '${dir.path}/$slug.zip';
          await File(path).writeAsBytes(zip);
          file = XFile(path);
      }
      await SharePlus.instance.share(ShareParams(files: [file]));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Export data', style: Theme.of(context).textTheme.titleLarge),
          Text(
            widget.group.name,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FormatCard(
            title: 'Project .zip',
            subtitle: 'Points, area, track and the photos. Self-contained.',
            selected: _format == _Format.project,
            onTap: () => setState(() => _format = _Format.project),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FormatCard(
            title: 'GeoJSON',
            subtitle: 'Points + tags + accuracy. Opens in QGIS.',
            selected: _format == _Format.geojson,
            onTap: () => setState(() => _format = _Format.geojson),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FormatCard(
            title: 'GPX',
            subtitle: 'Waypoints + your track. Opens in OsmAnd and Garmin.',
            selected: _format == _Format.gpx,
            onTap: () => setState(() => _format = _Format.gpx),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _busy ? 'Preparing…' : 'Export',
            onPressed: _busy ? null : _export,
          ),
        ],
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.paper : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.mist,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: selected ? AppColors.ink : AppColors.textFaint,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
