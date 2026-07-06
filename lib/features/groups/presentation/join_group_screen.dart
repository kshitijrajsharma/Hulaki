import 'dart:async';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/primary_button.dart';
import 'package:fieldchat/features/groups/invite_link.dart';
import 'package:fieldchat/features/groups/presentation/scan_qr_screen.dart';
import 'package:fieldchat/features/messaging/presentation/chat_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Join a group from an invite link. Paste the link a teammate shared; the key
/// in it decrypts the group, so no account or approval is needed.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ScanQrScreen()),
    );
    if (code == null || !mounted) return;
    _controller.text = code;
    await _join();
  }

  Future<void> _join() async {
    final link = _controller.text.trim();
    if (link.isEmpty || _busy) return;
    try {
      InviteLink.parse(link);
    } on FormatException {
      setState(() => _error = 'That is not a FieldChat invite link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      final group = await ref
          .read(groupServiceProvider)
          .joinViaLink(link, identity);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatThreadScreen(groupId: group.id, groupName: group.name),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a group')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste an invite link',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'A teammate can share it from a group under Members, Add.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                autocorrect: false,
                keyboardType: TextInputType.url,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'https://fieldchat.app/g/...',
                  errorText: _error,
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
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => unawaited(_scan()),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan a QR code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.mist),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: _busy ? 'Joining…' : 'Join',
                onPressed: _busy ? null : _join,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
