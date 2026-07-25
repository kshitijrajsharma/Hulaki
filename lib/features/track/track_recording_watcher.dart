import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/features/settings/background_run_provider.dart';
import 'package:hulaki/features/track/track_recording_controller.dart';

/// Keeps breadcrumb recording running across the app lifecycle. It records
/// while foregrounded, and while backgrounded only when the user has enabled
/// background mapping, so a minimised app with the running foreground service
/// keeps building the trail. Without the setting, backgrounding stops it.
class TrackRecordingWatcher extends ConsumerStatefulWidget {
  const TrackRecordingWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TrackRecordingWatcher> createState() =>
      _TrackRecordingWatcherState();
}

class _TrackRecordingWatcherState extends ConsumerState<TrackRecordingWatcher>
    with WidgetsBindingObserver {
  // Captured once: reading it back in dispose would rebuild a provider that
  // depends on the signed-in user, which is gone by teardown.
  late final TrackRecordingController _controller = ref.read(
    trackRecordingControllerProvider,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(controller.start());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!ref.read(backgroundRunProvider)) unawaited(controller.stop());
      case AppLifecycleState.detached:
        unawaited(controller.stop());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
