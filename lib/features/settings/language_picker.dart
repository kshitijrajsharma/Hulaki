import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/features/settings/locale_provider.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// Opens the language chooser. The choices come from whichever ARB files ship
/// in lib/l10n, so a new translation appears here with no code change.
Future<void> showLanguagePicker(BuildContext context) async {
  final names = await _languageNames();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => _LanguageSheet(names: names),
  );
}

/// Each language names itself, so the list reads in the reader's own script.
Future<Map<Locale, String>> _languageNames() async {
  final names = <Locale, String>{};
  for (final locale in AppLocalizations.supportedLocales) {
    names[locale] = (await AppLocalizations.delegate.load(locale)).languageName;
  }
  return names;
}

/// A compact tappable pill showing the current language. Placed on the first
/// screen so a new user can switch before onboarding, not only after it.
class LanguageChip extends ConsumerWidget {
  const LanguageChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: () => unawaited(showLanguagePicker(context)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 18, color: AppColors.ink),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.languageName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet({required this.names});

  final Map<Locale, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(localeProvider);
    return SafeArea(
      child: RadioGroup<Locale?>(
        groupValue: selected,
        onChanged: (value) => _choose(context, ref, value),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                l10n.meLanguage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RadioListTile<Locale?>(
              value: null,
              title: Text(l10n.meLanguageSystem),
            ),
            for (final entry in names.entries)
              RadioListTile<Locale?>(
                value: entry.key,
                title: Text(entry.value),
              ),
          ],
        ),
      ),
    );
  }

  void _choose(BuildContext context, WidgetRef ref, Locale? locale) {
    unawaited(ref.read(localeProvider.notifier).set(locale));
    Navigator.of(context).pop();
  }
}
