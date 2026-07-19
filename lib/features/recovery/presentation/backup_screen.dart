import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_snackbar.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/primary_button.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/auth/application/auth_state.dart';
import 'package:hulaki/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Shows a freshly generated recovery key once, after uploading the encrypted
/// backup. The key is the only way to restore the account, so it is never
/// stored on the device.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  late final Future<String> _keyFuture = _generate();

  Future<String> _generate() async {
    final identity = await ref.read(deviceIdentityProvider.future);
    final state = ref.read(authControllerProvider);
    if (state is! AuthSignedIn) throw StateError('No signed-in user');
    return ref
        .read(recoveryServiceProvider)
        .backUp(
          identity: identity,
          senderId: state.session.userId,
          username: state.session.username,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _keyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.backupFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return _KeyView(recoveryKey: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _KeyView extends StatelessWidget {
  const _KeyView({required this.recoveryKey});

  final String recoveryKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                l10n.backupHeading,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.backupBody,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.mist),
                ),
                child: SelectableText(
                  recoveryKey,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    letterSpacing: 1.5,
                    height: 1.7,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Action(
                icon: Icons.copy_outlined,
                label: l10n.backupCopy,
                onTap: () {
                  unawaited(
                    Clipboard.setData(ClipboardData(text: recoveryKey)),
                  );
                  context.showInfo(l10n.backupCopied);
                },
              ),
              _Action(
                icon: Icons.ios_share,
                label: l10n.backupShare,
                onTap: () => unawaited(
                  SharePlus.instance.share(ShareParams(text: recoveryKey)),
                ),
              ),
              _Action(
                icon: Icons.qr_code_2,
                label: l10n.backupShowQr,
                onTap: () => unawaited(_showQr(context, recoveryKey, l10n)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PrimaryButton(
            label: l10n.backupSaved,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );
  }

  Future<void> _showQr(
    BuildContext context,
    String key,
    AppLocalizations l10n,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: QrImageView(
            data: key,
            size: 240,
            backgroundColor: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
