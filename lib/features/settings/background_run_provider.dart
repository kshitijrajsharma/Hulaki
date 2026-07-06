import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _backgroundRunKey = 'settings.runInBackground';

/// Whether the app keeps mapping in the background through a foreground
/// service, persisted on the device. Off by default; the user turns it on from
/// the Me screen.
class BackgroundRunNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_backgroundRunKey) ??
        false;
  }

  Future<void> set({required bool value}) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_backgroundRunKey, value);
  }
}

final backgroundRunProvider = NotifierProvider<BackgroundRunNotifier, bool>(
  BackgroundRunNotifier.new,
);
