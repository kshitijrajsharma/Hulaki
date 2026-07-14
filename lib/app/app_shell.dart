import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/connectivity.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/chats/chats_home_screen.dart';
import 'package:hulaki/features/discovery/communities_screen.dart';
import 'package:hulaki/features/map/map_tab_screen.dart';
import 'package:hulaki/features/me/me_screen.dart';
import 'package:hulaki/features/onboarding/guided_tour.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// The four top-level destinations: Chats, Map, Communities and Me. Kept as a
/// single shell so the network and local state live above the tabs.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _communitiesIndex = 2;

  // Set by the tutorial path; the tour runs once, only for users who chose to
  // follow the tutorial (so the seeded sample and its plus button exist).
  static const _tourPendingKey = 'tour.pending';

  int _index = 0;
  final Set<int> _visited = {0};
  late bool _showTour =
      ref.read(sharedPreferencesProvider).getBool(_tourPendingKey) ?? false;

  List<TourStep> _tourSteps(AppLocalizations l10n) => [
    TourStep(
      tabIndex: 0,
      icon: Icons.chat_bubble_outline,
      title: l10n.tourChatsTitle,
      body: l10n.tourChatsBody,
    ),
    TourStep(
      tabIndex: 0,
      fab: true,
      icon: Icons.add,
      title: l10n.tourCreateTitle,
      body: l10n.tourCreateBody,
    ),
    TourStep(
      tabIndex: 1,
      icon: Icons.map_outlined,
      title: l10n.tourMapTitle,
      body: l10n.tourMapBody,
    ),
    TourStep(
      tabIndex: _communitiesIndex,
      icon: Icons.explore_outlined,
      title: l10n.tourCommunitiesTitle,
      body: l10n.tourCommunitiesBody,
    ),
    TourStep(
      tabIndex: 3,
      icon: Icons.person_outline,
      title: l10n.tourMeTitle,
      body: l10n.tourMeBody,
    ),
    TourStep(
      tabIndex: 0,
      sampleRow: true,
      icon: Icons.science_outlined,
      title: l10n.tourSampleTitle,
      body: l10n.tourSampleBody,
    ),
  ];

  Future<void> _finishTour() async {
    await ref.read(sharedPreferencesProvider).setBool(_tourPendingKey, false);
    if (mounted) setState(() => _showTour = false);
  }

  /// Builds a tab only once it has been opened, then keeps it alive in the
  /// stack. Defers the map's GL surface until the Map tab is first selected.
  Widget _tabAt(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => const ChatsHomeScreen(),
      1 => const MapTabScreen(),
      2 => const CommunitiesScreen(),
      _ => const MeScreen(),
    };
  }

  void _onTap(int value, String offlineMessage) {
    final online = ref.read(onlineProvider);
    if (value == _communitiesIndex && !online) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(offlineMessage)));
      return;
    }
    setState(() {
      _index = value;
      _visited.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = ref.watch(onlineProvider);
    final communitiesColor = online ? null : AppColors.textFaint;

    final scaffold = Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < 4; i++) _tabAt(i)],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (value) => _onTap(value, l10n.navCommunitiesNeedsConnection),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: l10n.navChats,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map),
            label: l10n.navMap,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined, color: communitiesColor),
            activeIcon: const Icon(Icons.explore),
            label: l10n.navCommunities,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.navMe,
          ),
        ],
      ),
    );

    if (!_showTour) return scaffold;
    return Stack(
      children: [
        scaffold,
        GuidedTour(
          steps: _tourSteps(l10n),
          itemCount: 4,
          onStep: (tab) => setState(() {
            _index = tab;
            _visited.add(tab);
          }),
          onFinish: _finishTour,
        ),
      ],
    );
  }
}
