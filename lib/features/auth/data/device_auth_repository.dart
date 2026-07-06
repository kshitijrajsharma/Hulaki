import 'package:fieldchat/features/auth/data/auth_repository.dart';
import 'package:fieldchat/features/auth/domain/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persists a device identity in SharedPreferences: a stable id created once,
/// and the username the user picks. This is the whole sign-in, no backend and
/// no SMS. Group access comes later from the invite link, not from an account.
class DeviceAuthRepository implements AuthRepository {
  DeviceAuthRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _userIdKey = 'session.userId';
  static const _usernameKey = 'session.username';
  static const _uuid = Uuid();

  @override
  Future<String> deviceUserId() async {
    final existing = _prefs.getString(_userIdKey);
    if (existing != null) return existing;
    final created = _uuid.v4();
    await _prefs.setString(_userIdKey, created);
    return created;
  }

  @override
  Future<Session> saveSession({
    required String userId,
    required String username,
  }) async {
    await _prefs.setString(_usernameKey, username);
    return Session(userId: userId, username: username);
  }

  @override
  Future<Session?> currentSession() async {
    final userId = _prefs.getString(_userIdKey);
    final username = _prefs.getString(_usernameKey);
    if (userId == null || username == null) return null;
    return Session(userId: userId, username: username);
  }

  @override
  Future<void> signOut() async {
    await _prefs.remove(_usernameKey);
  }
}
