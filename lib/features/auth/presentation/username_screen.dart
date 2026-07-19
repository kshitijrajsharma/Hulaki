import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/primary_button.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/auth/data/auth_repository.dart';
import 'package:hulaki/features/auth/domain/username.dart';
import 'package:hulaki/features/recovery/presentation/restore_screen.dart';
import 'package:hulaki/features/settings/language_picker.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// The whole sign-in: pick a handle and start. It is the name teammates see
/// in chat. No phone number, no password, no email.
class UsernameScreen extends ConsumerStatefulWidget {
  const UsernameScreen({super.key});

  @override
  ConsumerState<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends ConsumerState<UsernameScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim().toLowerCase();
    if (_busy) return;
    final localError = usernameError(value);
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(value);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

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
              const SizedBox(height: AppSpacing.md),
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: LanguageChip(),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.authWelcomeTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.authWelcomeSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-z0-9_]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  prefixText: '@',
                  hintText: l10n.authUsernameHint,
                  helperText: l10n.authUsernameHelper,
                  errorText: _error,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 14,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    borderSide: const BorderSide(color: AppColors.mist),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    borderSide: const BorderSide(
                      color: AppColors.ink,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              const Spacer(),
              PrimaryButton(
                label: _busy ? l10n.authSaving : l10n.commonContinue,
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RestoreScreen(),
                    ),
                  ),
                ),
                child: Text(
                  l10n.restoreLink,
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
