import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/capture/gps_gate.dart';
import 'package:hulaki/features/onboarding/demo_group.dart';
import 'package:hulaki/features/onboarding/how_it_works_screen.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// Shows the one-time how-it-works intro the first time a signed-in user
/// arrives, then reveals [child]. Tracked per device in preferences.
class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  static const _key = 'intro.seen';
  late bool _seen = ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  // Fallback centre (Kathmandu) used only when no location fix is available;
  // with no fix the map shows no user dot either, so there is no mismatch.
  static const _fallbackLat = 27.7172;
  static const _fallbackLng = 85.3240;

  Future<void> _finish({required bool seed}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (seed) {
      final l10n = AppLocalizations.of(context);
      final fix = await _firstFix();
      await seedDemoGroup(
        ref.read(databaseProvider),
        ref.read(currentUserIdProvider),
        l10n,
        centerLat: fix?.lat ?? _fallbackLat,
        centerLng: fix?.lng ?? _fallbackLng,
      );
      // The tour points at the seeded sample and its plus button, so it runs
      // only for users who followed the tutorial.
      await prefs.setBool('tour.pending', true);
    }
    await prefs.setBool(_key, true);
    if (mounted) setState(() => _seen = true);
  }

  /// One location fix so the sample can sit near the user. Null (fall back to a
  /// default) when permission is denied (stream closes empty) or no fix arrives
  /// in time.
  Future<GpsFix?> _firstFix() {
    return ref
        .read(gpsSourceProvider)
        .fixes()
        .cast<GpsFix?>()
        .firstWhere((_) => true, orElse: () => null)
        .timeout(const Duration(seconds: 6), onTimeout: () => null);
  }

  @override
  Widget build(BuildContext context) {
    if (_seen) return widget.child;
    return HowItWorksScreen(
      onFollowTutorial: () => _finish(seed: true),
      onSkip: () => _finish(seed: false),
    );
  }
}
