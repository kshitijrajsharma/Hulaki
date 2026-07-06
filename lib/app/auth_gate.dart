import 'package:fieldchat/app/app_shell.dart';
import 'package:fieldchat/app/background_service_watcher.dart';
import 'package:fieldchat/app/connectivity_watcher.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/auth/application/auth_state.dart';
import 'package:fieldchat/features/auth/presentation/username_screen.dart';
import 'package:fieldchat/features/onboarding/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Routes the top of the tree on auth state: splash while restoring,
/// onboarding when signed out, the shell when signed in.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return switch (state) {
      AuthLoading() => const SplashScreen(),
      AuthSignedOut() => const UsernameScreen(),
      AuthSignedIn() => const ConnectivityWatcher(
        child: BackgroundServiceWatcher(child: AppShell()),
      ),
    };
  }
}
