import 'dart:async';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/features/background/background_location_service.dart';
import 'package:fieldchat/features/capture/live_location.dart';
import 'package:fieldchat/features/settings/background_run_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backgroundLocationServiceProvider = Provider<BackgroundLocationService>(
  (ref) => BackgroundLocationService(),
);

/// Starts and stops the background mapping service to match the user's setting,
/// and feeds the live GPS accuracy into its notification. Mirrors the way the
/// connectivity watcher bridges device state into the app.
class BackgroundServiceWatcher extends ConsumerStatefulWidget {
  const BackgroundServiceWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BackgroundServiceWatcher> createState() =>
      _BackgroundServiceWatcherState();
}

class _BackgroundServiceWatcherState
    extends ConsumerState<BackgroundServiceWatcher> {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    ref.read(backgroundLocationServiceProvider).configure();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_apply(ref.read(backgroundRunProvider)));
    });
  }

  Future<void> _apply(bool enabled) async {
    final service = ref.read(backgroundLocationServiceProvider);
    if (enabled && !_running) {
      _running = true;
      await service.start();
    } else if (!enabled && _running) {
      _running = false;
      await service.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<bool>(backgroundRunProvider, (_, enabled) {
        unawaited(_apply(enabled));
      })
      ..listen<AsyncValue<LiveLocation>>(liveLocationProvider, (_, next) {
        final location = next.asData?.value;
        if (_running && location != null) {
          unawaited(
            ref
                .read(backgroundLocationServiceProvider)
                .reportAccuracy(location.accuracyM),
          );
        }
      });
    return widget.child;
  }
}
