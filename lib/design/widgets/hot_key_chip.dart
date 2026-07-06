import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:flutter/material.dart';

/// A tap-able tag. One tap captions a capture, sets its map colour and files
/// it under that tag. Selected fills with the tag colour; otherwise it shows
/// a tinted, outlined pill.
class HotKeyChip extends StatelessWidget {
  const HotKeyChip({
    required this.label,
    required this.color,
    this.icon,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = selected ? AppColors.white : color;
    final textColor = selected ? AppColors.white : color;

    return Material(
      color: selected ? color : color.withValues(alpha: 0.12),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: selected ? 0 : 0.55)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 15, color: dotColor)
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check, size: 15, color: AppColors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
