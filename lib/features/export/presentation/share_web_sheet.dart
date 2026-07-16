import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/primary_button.dart';
import 'package:hulaki/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

/// Publishes and manages read-only web links for a group's data. Each link is
/// an encrypted snapshot: anyone with it can view and download, and it works
/// until revoked.
class ShareWebSheet extends ConsumerStatefulWidget {
  const ShareWebSheet({required this.group, super.key});

  final Group group;

  @override
  ConsumerState<ShareWebSheet> createState() => _ShareWebSheetState();
}

class _ShareWebSheetState extends ConsumerState<ShareWebSheet> {
  bool _busy = false;

  /// Set when a refresh fails, shown inline since a snackbar would sit behind
  /// this sheet. Cleared on the next successful refresh.
  String? _updateError;

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(snapshotPublisherProvider)
          .publish(widget.group, now: DateTime.now());
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) _toast(AppLocalizations.of(context).shareWebCopied);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(String id) =>
      ref.read(snapshotPublisherProvider).revoke(id);

  Future<void> _update(WebSnapshot snapshot) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(snapshotPublisherProvider)
          .update(snapshot, now: DateTime.now());
      if (mounted) setState(() => _updateError = null);
    } on Exception {
      if (mounted) setState(() => _updateError = l10n.shareWebUpdateFailed);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.shareWebTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.shareWebBody,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _busy ? l10n.shareWebCreating : l10n.shareWebCreate,
            loading: _busy,
            onPressed: _busy ? null : _create,
          ),
          if (_updateError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _updateError!,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _ActiveLinks(
            groupId: widget.group.id,
            onRevoke: _revoke,
            onUpdate: _update,
          ),
        ],
      ),
    );
  }
}

class _ActiveLinks extends ConsumerWidget {
  const _ActiveLinks({
    required this.groupId,
    required this.onRevoke,
    required this.onUpdate,
  });

  final String groupId;
  final Future<void> Function(String id) onRevoke;
  final Future<void> Function(WebSnapshot snapshot) onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final publisher = ref.read(snapshotPublisherProvider);
    return StreamBuilder<List<WebSnapshot>>(
      stream: publisher.watchSnapshotsFor(groupId),
      builder: (context, snapshot) {
        final links = snapshot.data ?? const <WebSnapshot>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shareWebActiveLinks,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (links.isEmpty)
              Text(
                l10n.shareWebEmpty,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textFaint,
                ),
              )
            else
              for (final link in links)
                _LinkRow(
                  link: link,
                  onRevoke: () => onRevoke(link.id),
                  onUpdate: () => onUpdate(link),
                ),
          ],
        );
      },
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.onRevoke,
    required this.onUpdate,
  });

  final WebSnapshot link;
  final VoidCallback onRevoke;
  final Future<void> Function() onUpdate;

  String get _date {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = (link.updatedAt ?? link.createdAt).toLocal();
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.public, size: 20, color: AppColors.ink),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shareWebLinkLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  link.updatedAt != null
                      ? '${l10n.shareWebUpdatedLabel} $_date'
                      : _date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: AppColors.ink),
            tooltip: l10n.shareWebCopy,
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: link.url)));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.shareWebCopied)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, size: 18, color: AppColors.ink),
            tooltip: l10n.shareWebShare,
            onPressed: () => unawaited(
              SharePlus.instance.share(ShareParams(text: link.url)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync, size: 18, color: AppColors.ink),
            tooltip: l10n.shareWebUpdate,
            onPressed: () => unawaited(onUpdate()),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: AppColors.danger,
            ),
            tooltip: l10n.shareWebRevoke,
            onPressed: onRevoke,
          ),
        ],
      ),
    );
  }
}
