import 'package:fieldchat/features/auth/domain/session.dart';

/// Where the user stands with authentication. Drives the top-level routing.
sealed class AuthState {
  const AuthState();
}

/// The persisted session is still being restored.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No session; the onboarding flow is shown.
class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

/// A live session; the app shell is shown.
class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session);

  final Session session;
}
