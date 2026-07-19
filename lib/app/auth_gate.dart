import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/app_shell.dart';
import 'package:hulaki/app/background_service_watcher.dart';
import 'package:hulaki/app/connectivity_watcher.dart';
import 'package:hulaki/app/deep_link_watcher.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/auth/application/auth_state.dart';
import 'package:hulaki/features/auth/presentation/username_screen.dart';
import 'package:hulaki/features/notifications/join_request_watcher.dart';
import 'package:hulaki/features/onboarding/onboarding_gate.dart';
import 'package:hulaki/features/onboarding/splash_screen.dart';
import 'package:hulaki/features/recovery/presentation/backup_watcher.dart';

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
        child: BackgroundServiceWatcher(
          child: DeepLinkWatcher(
            child: JoinRequestWatcher(
              child: BackupWatcher(
                child: OnboardingGate(child: AppShell()),
              ),
            ),
          ),
        ),
      ),
    };
  }
}
