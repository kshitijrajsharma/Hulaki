import 'package:fieldchat/app/connectivity.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/features/chats/chats_home_screen.dart';
import 'package:fieldchat/features/discovery/communities_screen.dart';
import 'package:fieldchat/features/map/map_tab_screen.dart';
import 'package:fieldchat/features/me/me_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four top-level destinations: Chats, Map, Communities and Me. Kept as a
/// single shell so the network and local state live above the tabs.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _communitiesIndex = 2;

  int _index = 0;
  final Set<int> _visited = {0};

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

  void _onTap(int value) {
    final online = ref.read(onlineProvider);
    if (value == _communitiesIndex && !online) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Communities needs a connection.')),
        );
      return;
    }
    setState(() {
      _index = value;
      _visited.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(onlineProvider);
    final communitiesColor = online ? null : AppColors.textFaint;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < 4; i++) _tabAt(i)],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined, color: communitiesColor),
            activeIcon: const Icon(Icons.explore),
            label: 'Communities',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
