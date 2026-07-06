import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/discovery/group_preview_screen.dart';
import 'package:fieldchat/features/discovery/place_line.dart';
import 'package:fieldchat/features/discovery/public_directory.dart';
import 'package:fieldchat/features/groups/presentation/group_avatar.dart';
import 'package:fieldchat/features/settings/units.dart';
import 'package:fieldchat/features/settings/units_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public groups mapping near the user, from the shared directory. A top-level
/// tab: tap a group to preview it, then join and start contributing.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  Future<List<PublicGroup>>? _future;

  void _load(double lat, double lng) {
    _future = ref
        .read(publicDirectoryProvider)
        .nearby(lat: lat, lng: lng, radiusKm: 25);
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveLocationProvider).asData?.value;
    final units = ref.watch(unitsProvider);
    if (live != null && _future == null) {
      _load(live.lat, live.lng);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text(
          'Communities',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: live == null
          ? const _Centered('Finding your location…', spinner: true)
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _load(live.lat, live.lng));
                await _future;
              },
              child: FutureBuilder<List<PublicGroup>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _Centered('Looking nearby…', spinner: true);
                  }
                  final groups = snapshot.data ?? const <PublicGroup>[];
                  if (groups.isEmpty) {
                    return const _Centered(
                      'No public groups nearby yet. Start one and make it '
                      'public to put it on the map.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) =>
                        _NearbyTile(group: groups[i], units: units),
                  );
                },
              ),
            ),
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
