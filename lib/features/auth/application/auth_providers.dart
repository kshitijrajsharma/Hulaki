import 'package:fieldchat/features/auth/application/auth_controller.dart';
import 'package:fieldchat/features/auth/application/auth_state.dart';
import 'package:fieldchat/features/auth/data/auth_repository.dart';
import 'package:fieldchat/features/auth/data/device_auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The loaded SharedPreferences instance. Overridden at app start; tests
/// override it with a mocked instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

/// The device-identity auth backend, persisting to SharedPreferences.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DeviceAuthRepository(ref.watch(sharedPreferencesProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
