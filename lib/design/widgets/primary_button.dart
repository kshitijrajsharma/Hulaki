import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:flutter/material.dart';

/// The ink call-to-action used for the one primary action on a screen:
/// Continue, Create group, Export. Full width by default.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.trailingIcon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final foreground = disabled ? AppColors.textFaint : AppColors.white;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: disabled ? AppColors.mist : AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.field),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailingIcon, size: 18, color: foreground),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
