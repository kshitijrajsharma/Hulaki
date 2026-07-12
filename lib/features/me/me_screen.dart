import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/auth/application/auth_state.dart';
import 'package:hulaki/features/map/offline_areas.dart';
import 'package:hulaki/features/map/offline_downloads.dart';
import 'package:hulaki/features/settings/background_run_provider.dart';
import 'package:hulaki/features/settings/locale_provider.dart';
import 'package:hulaki/features/settings/privacy_provider.dart';
import 'package:hulaki/features/settings/units.dart';
import 'package:hulaki/features/settings/units_provider.dart';
import 'package:hulaki/l10n/app_localizations.dart';
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

  /// Reaches the child safety point of contact published at
  /// kshitijrajsharma.github.io/Hulaki/child-safety.html.
  static final Uri _reportUri = Uri.parse(
    'mailto:krschap@proton.me?subject=Safety%20report',
  );

  Future<void> _openLink(Uri uri, String failureMessage) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  /// The size-and-expiry line under a saved area, for example "12.4 MB ·
  /// expires in 21 days".
  String _areaDetail(AppLocalizations l10n, CachedArea area) {
    final parts = <String>[_formatBytes(l10n, area.sizeBytes)];
    final expiresAt = area.expiresAt;
    if (expiresAt != null) {
      final days = expiresAt.difference(DateTime.now()).inDays;
      parts.add(
        days <= 0 ? l10n.meAreaExpiresToday : l10n.meAreaExpiresInDays(days),
      );
    }
    return parts.join(' · ');
  }

  String _formatBytes(AppLocalizations l10n, int bytes) {
    if (bytes < 1024) return l10n.meSizeBytes('$bytes');
    if (bytes < 1024 * 1024) {
      return l10n.meSizeKilobytes((bytes / 1024).toStringAsFixed(0));
    }
    return l10n.meSizeMegabytes((bytes / (1024 * 1024)).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final downloads = ref.watch(offlineDownloadsProvider);
    // A finished download leaves the active list, so reload the saved areas to
    // pull in the newly cached one with its size and expiry.
    ref.listen(offlineDownloadsProvider, (previous, next) {
      if ((previous?.isNotEmpty ?? false) && next.isEmpty) _reloadAreas();
    });
    final username = authState is AuthSignedIn
        ? authState.session.username
        : l10n.commonYou;
    final units = ref.watch(unitsProvider);
    final version = ref.watch(appVersionProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text(
          l10n.navMe,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ProfileCard(
            username: username,
            anonymous: ref.watch(appearAnonymousProvider),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.meSectionUnits),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: _UnitsToggle(
              units: units,
              onChanged: (value) =>
                  unawaited(ref.read(unitsProvider.notifier).set(value)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.meSectionLanguage),
          const SizedBox(height: AppSpacing.sm),
          const _Card(child: _LanguageTile()),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.meSectionPrivacy),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.meAppearAnonymous,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                l10n.meAppearAnonymousSubtitle,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              value: ref.watch(appearAnonymousProvider),
              onChanged: (value) => unawaited(
                ref.read(appearAnonymousProvider.notifier).set(value: value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.meSectionBackground),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.meRunInBackground,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                l10n.meRunInBackgroundSubtitle,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              value: ref.watch(backgroundRunProvider),
              onChanged: (value) => unawaited(
                ref.read(backgroundRunProvider.notifier).set(value: value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.meSectionOfflineAreas),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      l10n.meNoAreasSaved,
                      style: const TextStyle(
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
                        detail: _areaDetail(l10n, area),
                        onRemove: () => _remove(area.id),
                      ),
                  ],
                );
              },
            ),
          ),
          const _ArchivedGroups(),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel(l10n.meSectionSupport),
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: InkWell(
              onTap: () => unawaited(
                _openLink(_supportUri, l10n.meCouldNotOpenLink),
              ),
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
                        Text(
                          l10n.meSupportTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.meSupportSubtitle,
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
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: InkWell(
              onTap: () => unawaited(
                _openLink(_reportUri, l10n.meCouldNotOpenLink),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.meReportTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.meReportSubtitle,
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
    final l10n = AppLocalizations.of(context);
    final name = username.isNotEmpty ? username : l10n.commonYou;
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
                anonymous ? l10n.meAnonymousModeOn : l10n.meSignedInOnDevice,
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
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.meDistanceAndElevation,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        _Segment(
          label: l10n.meUnitsMetric,
          selected: units == UnitSystem.metric,
          onTap: () => onChanged(UnitSystem.metric),
        ),
        const SizedBox(width: 6),
        _Segment(
          label: l10n.meUnitsImperial,
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
    final l10n = AppLocalizations.of(context);
    final groups =
        ref.watch(archivedGroupsProvider).asData?.value ?? const <Group>[];
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        _SectionLabel(l10n.meSectionArchivedGroups),
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
                    child: Text(l10n.meRestore),
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
    final l10n = AppLocalizations.of(context);
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
            l10n.meDownloadPercent(percent),
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

/// Language row. The choices come from whichever ARB files ship in lib/l10n, so
/// a new translation appears here with no code change.
class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(localeProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        l10n.meLanguage,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        selected == null ? l10n.meLanguageSystem : l10n.languageName,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textFaint),
      onTap: () => unawaited(_pickLanguage(context, ref)),
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final names = await _languageNames();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _LanguageSheet(names: names),
    );
  }

  /// Each language names itself, so the list reads in the reader's own script.
  static Future<Map<Locale, String>> _languageNames() async {
    final names = <Locale, String>{};
    for (final locale in AppLocalizations.supportedLocales) {
      names[locale] = (await AppLocalizations.delegate.load(
        locale,
      )).languageName;
    }
    return names;
  }
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet({required this.names});

  final Map<Locale, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(localeProvider);
    return SafeArea(
      child: RadioGroup<Locale?>(
        groupValue: selected,
        onChanged: (value) => _choose(context, ref, value),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                l10n.meLanguage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioListTile<Locale?>(
              value: null,
              title: Text(l10n.meLanguageSystem),
            ),
            for (final entry in names.entries)
              RadioListTile<Locale?>(
                value: entry.key,
                title: Text(entry.value),
              ),
          ],
        ),
      ),
    );
  }

  void _choose(BuildContext context, WidgetRef ref, Locale? locale) {
    unawaited(ref.read(localeProvider.notifier).set(locale));
    Navigator.of(context).pop();
  }
}
