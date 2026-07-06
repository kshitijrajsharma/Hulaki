import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-time hint shown the first time a user reaches a screen. Once dismissed
/// it stays hidden, tracked per [tipKey] on the device.
class CoachTip extends ConsumerStatefulWidget {
  const CoachTip({
    required this.tipKey,
    required this.message,
    this.translucent = false,
    super.key,
  });

  final String tipKey;
  final String message;

  /// Softens the background so the tip reads over dark satellite imagery. Left
  /// off over light surfaces like the chat window, where opaque looks cleaner.
  final bool translucent;

  @override
  ConsumerState<CoachTip> createState() => _CoachTipState();
}

class _CoachTipState extends ConsumerState<CoachTip> {
  late bool _visible =
      !(ref.read(sharedPreferencesProvider).getBool('tip.${widget.tipKey}') ??
          false);

  Future<void> _dismiss() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('tip.${widget.tipKey}', true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: widget.translucent ? 0.85 : 1),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.amber),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.message,
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
