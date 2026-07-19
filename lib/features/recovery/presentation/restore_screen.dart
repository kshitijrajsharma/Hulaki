import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/primary_button.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/recovery/recovery_service.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// Restores an account from a recovery key. On success the identity, sender id,
/// username and groups are rebuilt, and the app drops into the signed-in shell.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final _controller = TextEditingController();
  bool _restoring = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restore(AppLocalizations l10n) async {
    final recovery = ref.read(recoveryServiceProvider);
    final key = _controller.text.trim();
    if (!ref.read(backupCryptoProvider).isValidKey(key)) {
      setState(() => _error = l10n.restoreInvalid);
      return;
    }
    setState(() {
      _restoring = true;
      _error = null;
    });
    try {
      await recovery.restore(key);
      await ref
          .read(sharedPreferencesProvider)
          .setBool('recovery.backedUp', true);
      ref
        ..invalidate(deviceIdentityProvider)
        ..invalidate(authControllerProvider);
      if (mounted) Navigator.of(context).pop();
    } on RecoveryNotFound {
      if (mounted) setState(() => _error = l10n.restoreNotFound);
    } on SecretBoxAuthenticationError {
      if (mounted) setState(() => _error = l10n.restoreInvalid);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.restoreTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(
                    l10n.restoreHeading,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.restoreBody,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _controller,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.restoreHint,
                      filled: true,
                      fillColor: AppColors.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        borderSide: const BorderSide(color: AppColors.mist),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        borderSide: const BorderSide(color: AppColors.mist),
                      ),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: PrimaryButton(
                label: l10n.restoreButton,
                loading: _restoring,
                onPressed: _restoring ? null : () => unawaited(_restore(l10n)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
