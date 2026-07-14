import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/pill_toggle.dart';
import 'package:hulaki/features/capture/live_location.dart';
import 'package:hulaki/features/discovery/group_preview_screen.dart';
import 'package:hulaki/features/discovery/place_line.dart';
import 'package:hulaki/features/discovery/public_directory.dart';
import 'package:hulaki/features/groups/presentation/group_avatar.dart';
import 'package:hulaki/features/settings/units.dart';
import 'package:hulaki/features/settings/units_provider.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// Public groups mapping near the user, from the shared directory. A top-level
/// tab: tap a group to preview it, then join and start contributing.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final _searchController = TextEditingController();
  Future<List<PublicGroup>>? _future;
  Future<List<PublicGroup>>? _globalFuture;
  Future<List<PublicGroup>>? _searchFuture;
  Timer? _debounce;
  String _query = '';
  String _tab = 'nearby';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _load(double lat, double lng) {
    _future = ref
        .read(publicDirectoryProvider)
        .nearby(lat: lat, lng: lng, radiusKm: 25);
  }

  void _loadGlobal() {
    _globalFuture = ref.read(publicDirectoryProvider).globalFeed();
  }

  /// Debounces typing, then searches the directory by name. A blank query
  /// falls back to the nearby list.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = value.trim();
      setState(() {
        _query = query;
        _searchFuture = query.isEmpty
            ? null
            : ref.read(publicDirectoryProvider).searchByName(query);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final live = ref.watch(liveLocationProvider).asData?.value;
    final units = ref.watch(unitsProvider);
    if (live != null && _future == null) {
      _load(live.lat, live.lng);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text(
          l10n.discoverTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: _SearchField(
              controller: _searchController,
              onChanged: _onQueryChanged,
            ),
          ),
          if (_query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Center(
                child: PillToggle(
                  left: l10n.discoverNearby,
                  right: l10n.discoverGlobal,
                  rightSelected: _tab == 'global',
                  onChanged: (global) {
                    setState(() {
                      _tab = global ? 'global' : 'nearby';
                      if (_tab == 'global' && _globalFuture == null) {
                        _loadGlobal();
                      }
                    });
                  },
                ),
              ),
            ),
          Expanded(
            child: _query.isNotEmpty
                ? _searchSection(l10n, units)
                : _tab == 'nearby'
                ? _nearbySection(l10n, live, units)
                : _globalSection(l10n, units),
          ),
        ],
      ),
    );
  }

  Widget _globalSection(AppLocalizations l10n, UnitSystem units) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(_loadGlobal);
        await _globalFuture;
      },
      child: FutureBuilder<List<PublicGroup>>(
        future: _globalFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _Centered(l10n.discoverLoadingGlobal, spinner: true);
          }
          final groups = snapshot.data ?? const <PublicGroup>[];
          if (groups.isEmpty) {
            return _Centered(l10n.discoverNoGlobalGroups);
          }
          return _GroupList(groups: groups, units: units);
        },
      ),
    );
  }

  Widget _nearbySection(
    AppLocalizations l10n,
    LiveLocation? live,
    UnitSystem units,
  ) {
    if (live == null) {
      return _Centered(l10n.discoverFindingLocation, spinner: true);
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _load(live.lat, live.lng));
        await _future;
      },
      child: FutureBuilder<List<PublicGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _Centered(l10n.discoverLookingNearby, spinner: true);
          }
          final groups = snapshot.data ?? const <PublicGroup>[];
          if (groups.isEmpty) {
            return _Centered(l10n.discoverNoNearbyGroups);
          }
          return _GroupList(groups: groups, units: units);
        },
      ),
    );
  }

  Widget _searchSection(AppLocalizations l10n, UnitSystem units) {
    return FutureBuilder<List<PublicGroup>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _Centered(l10n.discoverSearching, spinner: true);
        }
        final groups = snapshot.data ?? const <PublicGroup>[];
        if (groups.isEmpty) {
          return _Centered(l10n.discoverNoSearchResults(_query));
        }
        return _GroupList(groups: groups, units: units);
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context).discoverSearchHint,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.mist),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups, required this.units});

  final List<PublicGroup> groups;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _NearbyTile(group: groups[i], units: units),
    );
  }
}

class _NearbyTile extends StatelessWidget {
  const _NearbyTile({required this.group, required this.units});

  final PublicGroup group;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final description = group.description;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GroupPreviewScreen(group: group),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.mist),
          ),
          child: Row(
            children: [
              const GroupAvatar(photo: null, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GroupPlaceLine(group: group, units: units),
                    if (description != null && description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.message, {this.spinner = false});

  final String message;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
