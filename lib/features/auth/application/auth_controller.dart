import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/auth/application/auth_state.dart';
import 'package:fieldchat/features/auth/data/auth_repository.dart';
import 'package:fieldchat/features/auth/domain/username.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the auth state. Restores any persisted session on creation, then
/// exposes the single onboarding action.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(_restore());
    return const AuthLoading();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final session = await _repository.currentSession();
    if (state is! AuthLoading) return;
    state = session == null ? const AuthSignedOut() : AuthSignedIn(session);
  }

  /// Validates and claims [raw] as the handle for this device, writes the
  /// profile, then enters the shell. Throws [AuthException] on a bad or taken
  /// name.
  Future<void> register(String raw) async {
    final username = raw.trim().toLowerCase();
    final error = usernameError(username);
    if (error != null) throw AuthException(error);

    final userId = await _repository.deviceUserId();
    final db = ref.read(databaseProvider);
    final taken = await db.profileByUsername(username);
    if (taken != null && taken.id != userId) {
      throw const AuthException('That username is taken.');
    }
    await db.upsertProfile(
      ProfilesCompanion.insert(
        id: userId,
        phone: '',
        displayName: Value(username),
      ),
    );
    state = AuthSignedIn(
      await _repository.saveSession(userId: userId, username: username),
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthSignedOut();
  }
}
