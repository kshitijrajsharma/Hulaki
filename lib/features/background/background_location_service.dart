import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point for the service isolate. Kept minimal: the live GPS updates come
/// from the main isolate, which the foreground service keeps alive.
@pragma('vm:entry-point')
void startBackgroundCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Runs an Android foreground service (and the iOS background task) so mapping
/// continues with the screen off. The persistent notification reports the live
/// GPS accuracy, updated from the main isolate as fixes arrive.
class BackgroundLocationService {
  static const _title = 'FieldChat is mapping';
  static const _channelId = 'fieldchat_mapping';

  void configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Background mapping',
        channelDescription:
            'Shown while FieldChat keeps mapping in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWifiLock: true,
      ),
    );
  }

  Future<void> start() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 512,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: _title,
      notificationText: 'Getting GPS…',
      callback: startBackgroundCallback,
    );
  }

  Future<void> reportAccuracy(double accuracyM) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: _title,
      notificationText: 'GPS fixed · ±${accuracyM.round()} m',
    );
  }

  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
