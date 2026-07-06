import 'package:fieldchat/design/app_colors.dart';
import 'package:flutter/material.dart';

/// Font families bundled with the app. Hanken Grotesk carries the wordmark
/// and the whole interface; Caveat is the occasional handwritten accent.
abstract final class AppFonts {
  const AppFonts._();

  static const String sans = 'HankenGrotesk';
  static const String accent = 'Caveat';
}

/// The FieldChat text scale. Regular for body, SemiBold for labels,
/// ExtraBold for the wordmark and numbers.
TextTheme buildTextTheme() {
  return const TextTheme(
    displaySmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 40,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      color: AppColors.ink,
    ),
    headlineSmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    labelMedium: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: AppColors.textMuted,
    ),
    labelSmall: TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
    ),
  );
}

/// The handwritten accent style, used sparingly for tag lines and hints.
const TextStyle accentStyle = TextStyle(
  fontFamily: AppFonts.accent,
  fontSize: 19,
  fontWeight: FontWeight.w600,
  color: AppColors.textMuted,
);
