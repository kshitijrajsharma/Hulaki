import 'package:flutter/material.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/primary_button.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// The one-time introduction shown the first time a signed-in user reaches the
/// app: the core loop in three steps, so a new mapper knows what to do.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({
    required this.onFollowTutorial,
    required this.onSkip,
    super.key,
  });

  /// Seeds the sample group and enters the app.
  final VoidCallback onFollowTutorial;

  /// Enters the app with no sample.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              Text(
                l10n.introTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.introSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _Step(
                icon: Icons.groups_outlined,
                title: l10n.introStep1Title,
                body: l10n.introStep1Body,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Step(
                icon: Icons.add_location_alt_outlined,
                title: l10n.introStep2Title,
                body: l10n.introStep2Body,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Step(
                icon: Icons.map_outlined,
                title: l10n.introStep3Title,
                body: l10n.introStep3Body,
              ),
              const SizedBox(height: AppSpacing.xl),
              _Step(
                icon: Icons.explore_outlined,
                title: l10n.introStep4Title,
                body: l10n.introStep4Body,
              ),
              const Spacer(),
              PrimaryButton(
                label: l10n.introFollowTutorial,
                onPressed: onFollowTutorial,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  l10n.introSkip,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Icon(icon, color: AppColors.ink, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
