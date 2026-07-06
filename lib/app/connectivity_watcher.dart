import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fieldchat/app/connectivity.dart';
import 'package:fieldchat/app/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reflects the device network state into the app: updates the offline banner
/// and drives sync (queue when offline, drain and catch up when back).
class ConnectivityWatcher extends ConsumerStatefulWidget {
  const ConnectivityWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ConnectivityWatcher> createState() =>
      _ConnectivityWatcherState();
}

class _ConnectivityWatcherState extends ConsumerState<ConnectivityWatcher> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_listen());
  }

  Future<void> _listen() async {
    final connectivity = Connectivity();
    try {
      _apply(await connectivity.checkConnectivity());
      _subscription = connectivity.onConnectivityChanged.listen(_apply);
    } on MissingPluginException {
      // No connectivity plugin (e.g., the test harness): assume online.
      _apply(const [ConnectivityResult.wifi]);
    }
  }

  void _apply(List<ConnectivityResult> results) {
    if (!mounted) return;
    final online = results.any((r) => r != ConnectivityResult.none);
    ref.read(onlineProvider.notifier).online = online;
    unawaited(ref.read(syncServiceProvider).setOnline(value: online));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
