import 'dart:async';

import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:flutter/material.dart';

class GpsStrip extends StatefulWidget {
  const GpsStrip({
    required this.accuracyMeters,
    this.alertAbove = 15,
    this.onTap,
    this.pulseKey,
    super.key,
  });

  final double? accuracyMeters;
  final double alertAbove;
  final VoidCallback? onTap;
  final Object? pulseKey;

  @override
  State<GpsStrip> createState() => _GpsStripState();
}

class _GpsStripState extends State<GpsStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final Animation<double> _beat = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.3,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.3,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 65,
    ),
  ]).animate(_pulse);

  late final Animation<double> _dotFlash = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.35,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0.35,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 65,
    ),
  ]).animate(_pulse);

  bool get _acquiring => widget.accuracyMeters == null;
  bool get _strong =>
      widget.accuracyMeters != null &&
      widget.accuracyMeters! <= widget.alertAbove;

  @override
  void didUpdateWidget(GpsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_acquiring && widget.pulseKey != oldWidget.pulseKey) {
      unawaited(_pulse.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

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
      onTap: widget.onTap,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                ScaleTransition(
                  scale: _beat,
                  child: _SignalBars(color: tone),
                ),
                if (!_acquiring)
                  Positioned(
                    top: -3,
                    right: -4,
                    child: FadeTransition(
                      opacity: _dotFlash,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
                '±${widget.accuracyMeters!.round()} m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            if (widget.onTap != null) ...[
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
