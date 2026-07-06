import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _anonKey = 'settings.appearAnonymous';

/// When true, outgoing messages carry no name, so teammates see the sender as
/// an anonymous member. Off by default. Persisted on the device.
class AppearAnonymousNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_anonKey) ?? false;

  Future<void> set({required bool value}) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_anonKey, value);
  }
}

final appearAnonymousProvider = NotifierProvider<AppearAnonymousNotifier, bool>(
  AppearAnonymousNotifier.new,
);
