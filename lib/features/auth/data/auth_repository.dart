import 'package:fieldchat/features/auth/domain/session.dart';

/// Device-identity authentication. Each install holds a stable id and a chosen
/// username, persisted locally. No phone number or SMS is involved.
abstract interface class AuthRepository {
  /// The stable per-device id, created and persisted on first use.
  Future<String> deviceUserId();

  /// Persists [username] against the device id and returns the session.
  Future<Session> saveSession({
    required String userId,
    required String username,
  });

  /// The persisted session, or null when no username has been chosen yet.
  Future<Session?> currentSession();

  /// Clears the chosen username, returning to onboarding on this device.
  Future<void> signOut();
}

/// Raised when a chosen username is rejected. The message is safe to show.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
