import 'dart:async';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/auth/application/auth_state.dart';
import 'package:fieldchat/features/map/offline_areas.dart';
import 'package:fieldchat/features/map/offline_downloads.dart';
import 'package:fieldchat/features/settings/background_run_provider.dart';
import 'package:fieldchat/features/settings/privacy_provider.dart';
import 'package:fieldchat/features/settings/units.dart';
import 'package:fieldchat/features/settings/units_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The account tab: who you are, the areas saved for offline use, and the
/// project's support link.
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  late Future<List<CachedArea>> _areasFuture = cachedGroupAreas();

  void _reloadAreas() {
    setState(() {
      _areasFuture = cachedGroupAreas();
    });
  }

  Future<void> _remove(int id) async {
    await removeCachedRegion(id);
    _reloadAreas();
  }

  static final Uri _supportUri = Uri.parse(
    'https://github.com/sponsors/kshitijrajsharma',
  );

  Future<void> _openSupport() async {
    final ok = await launchUrl(
      _supportUri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  /// The size-and-expiry line under a saved area, for example "12.4 MB ·
  /// expires in 21 days".
  String _areaDetail(CachedArea area) {
    final parts = <String>[_formatBytes(area.sizeBytes)];
    final expiresAt = area.expiresAt;
    if (expiresAt != null) {
      final days = expiresAt.difference(DateTime.now()).inDays;
      parts.add(days <= 0 ? 'expires today' : 'expires in $days days');
    }
    return parts.join(' · ');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final downloads = ref.watch(offlineDownloadsProvider);
    // A finished download leaves the active list, so reload the saved areas to
    // pull in the newly cached one with its size and expiry.
    ref.listen(offlineDownloadsProvider, (previous, next) {
      if ((previous?.isNotEmpty ?? false) && next.isEmpty) _reloadAreas();
    });
    final username = authState is AuthSignedIn
        ? authState.session.username
        : 'You';
    final units = ref.watch(unitsProvider);
    final version = ref.watch(appVersionProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text('Me', style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ProfileCard(
            username: username,
            anonymous: ref.watch(appearAnonymousProvider),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('UNITS'),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: _UnitsToggle(
              units: units,
              onChanged: (value) =>
                  unawaited(ref.read(unitsProvider.notifier).set(value)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('PRIVACY'),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Appear anonymous',
                style: TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                'Teammates see your points without your name.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              value: ref.watch(appearAnonymousProvider),
              onChanged: (value) => unawaited(
                ref.read(appearAnonymousProvider.notifier).set(value: value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('BACKGROUND'),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Run in background',
                style: TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                'Keep mapping with the screen off. A notification shows the '
                'live GPS accuracy.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              value: ref.watch(backgroundRunProvider),
              onChanged: (value) => unawaited(
                ref.read(backgroundRunProvider.notifier).set(value: value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('OFFLINE AREAS'),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: FutureBuilder<List<CachedArea>>(
              future: _areasFuture,
              builder: (context, snapshot) {
                final areas = snapshot.data;
                if (areas == null && downloads.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                if (downloads.isEmpty && (areas == null || areas.isEmpty)) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'No areas saved yet. Open a group, then '
                      '“Make available offline”.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final download in downloads)
                      _DownloadRow(
                        name: download.groupName,
                        progress: download.progress,
                      ),
                    for (final area in areas ?? const <CachedArea>[])
                      _RegionRow(
                        name: area.name,
                        detail: _areaDetail(area),
                        onRemove: () => _remove(area.id),
                      ),
                  ],
                );
              },
            ),
          ),
          const _ArchivedGroups(),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('SUPPORT'),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: InkWell(
              onTap: _openSupport,
              child: Row(
                children: [
                  const Icon(
                    Icons.favorite_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Support the developer',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Star or sponsor the project on GitHub.',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                const Text(
                  '© 2026 Kshitij Raj Sharma · AGPL-3.0',
                  style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                ),
                if (version != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'v$version',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.username, required this.anonymous});

  final String username;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    final name = username.isNotEmpty ? username : 'You';
    final initial = name.characters.first.toUpperCase();
    return _Card(
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ),
                if (anonymous)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_off,
                        size: 14,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                anonymous ? 'Anonymous mode on' : 'Signed in on this device',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnitsToggle extends StatelessWidget {
  const _UnitsToggle({required this.units, required this.onChanged});

  final UnitSystem units;
  final ValueChanged<UnitSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('Distance and elevation', style: TextStyle(fontSize: 13)),
        ),
        _Segment(
          label: 'Metric',
          selected: units == UnitSystem.metric,
          onTap: () => onChanged(UnitSystem.metric),
        ),
        const SizedBox(width: 6),
        _Segment(
          label: 'Imperial',
          selected: units == UnitSystem.imperial,
          onTap: () => onChanged(UnitSystem.imperial),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.mist),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchivedGroups extends ConsumerWidget {
  const _ArchivedGroups();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups =
        ref.watch(archivedGroupsProvider).asData?.value ?? const <Group>[];
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const _SectionLabel('ARCHIVED GROUPS'),
        const SizedBox(height: AppSpacing.sm),
        _Card(
          child: Column(
            children: [
              for (final group in groups)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.archive_outlined,
                    size: 20,
                    color: AppColors.ink,
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: TextButton(
                    onPressed: () => unawaited(
                      ref.read(groupServiceProvider).unarchiveGroup(group.id),
                    ),
                    child: const Text('Restore'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.name,
    required this.detail,
    required this.onRemove,
  });

  final String name;
  final String detail;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.map_outlined, size: 20, color: AppColors.ink),
      title: Text(name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        detail,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_outline,
          size: 20,
          color: AppColors.danger,
        ),
        onPressed: onRemove,
      ),
    );
  }
}

/// A group's area mid-download, showing how far the tile cache has progressed.
class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.name, required this.progress});

  final String name;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.download_outlined, size: 20, color: AppColors.ink),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 5,
                    backgroundColor: AppColors.mist,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '$percent%',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelMedium);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.mist),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}
