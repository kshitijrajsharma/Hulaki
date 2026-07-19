import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/auth_gate.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/design/app_theme.dart';
import 'package:hulaki/features/settings/locale_provider.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// Application root. Holds the theme and the top-level navigation surface.
///
/// The supported languages come from whichever ARB files exist in lib/l10n, so
/// a new translation needs no change here.
class HulakiApp extends ConsumerStatefulWidget {
  const HulakiApp({super.key});

  @override
  ConsumerState<HulakiApp> createState() => _HulakiAppState();
}

class _HulakiAppState extends ConsumerState<HulakiApp> {
  @override
  void initState() {
    super.initState();
    // Generate the device identity during launch so the first action that
    // needs it (a join request, publishing) is instant rather than stalled on
    // the one-time key generation, which otherwise reads as a dead first tap.
    ref.read(deviceIdentityProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hulaki',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}
