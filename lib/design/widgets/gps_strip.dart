import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:flutter/material.dart';

/// Accuracy travels with every point. This strip shows the live GPS state
/// as signal bars plus a +/- metres badge. Green when strong, amber when the
/// fix is poor, muted while still acquiring (null accuracy).
class GpsStrip extends StatelessWidget {
  const GpsStrip({
    required this.accuracyMeters,
    this.alertAbove = 15,
    this.onTap,
    super.key,
  });

  final double? accuracyMeters;
  final double alertAbove;
  final VoidCallback? onTap;

  bool get _acquiring => accuracyMeters == null;
  bool get _strong => accuracyMeters != null && accuracyMeters! <= alertAbove;

  @override
  Widget build(BuildContext context) {
    final Color tone;
    final String label;
    if (_acquiring) {
      tone = AppColors.textMuted;
      label = 'Locating GPS…';
    } else if (_strong) {
      tone = AppColors.gpsStrong;
      label = 'GPS strong';
    } else {
      tone = AppColors.amber;
      label = 'GPS weak';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            _SignalBars(color: tone),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
            const Spacer(),
            if (!_acquiring)
              Text(
                '±${accuracyMeters!.round()} m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 15, color: tone),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <double>[4, 7, 10].map((h) {
        return Padding(
          padding: const EdgeInsets.only(right: 1.5),
          child: Container(width: 2.5, height: h, color: color),
        );
      }).toList(),
    );
  }
}
