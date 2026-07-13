import 'package:flutter/material.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// One stop on the guided tour: a bottom-nav destination ([tabIndex]), or the
/// Chats floating action button when [fab] is set, plus the words to show.
class TourStep {
  const TourStep({
    required this.tabIndex,
    required this.icon,
    required this.title,
    required this.body,
    this.fab = false,
  });

  final int tabIndex;
  final IconData icon;
  final String title;
  final String body;
  final bool fab;
}

/// A one-time spotlight tour that dims the app and lights up one destination at
/// a time. [onStep] switches the visible tab per stop; [onFinish] ends it.
class GuidedTour extends StatefulWidget {
  const GuidedTour({
    required this.steps,
    required this.itemCount,
    required this.onStep,
    required this.onFinish,
    super.key,
  });

  final List<TourStep> steps;
  final int itemCount;
  final ValueChanged<int> onStep;
  final VoidCallback onFinish;

  @override
  State<GuidedTour> createState() => _GuidedTourState();
}

class _GuidedTourState extends State<GuidedTour> {
  static const _fabSize = 56.0;
  static const _fabMargin = 16.0;

  int _current = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStep(widget.steps.first.tabIndex);
    });
  }

  void _next() {
    if (_current >= widget.steps.length - 1) {
      widget.onFinish();
      return;
    }
    final next = _current + 1;
    setState(() => _current = next);
    widget.onStep(widget.steps[next].tabIndex);
  }

  Rect _targetRect(BuildContext context) {
    final media = MediaQuery.of(context);
    const navHeight = kBottomNavigationBarHeight;
    final navTop = media.size.height - media.viewPadding.bottom - navHeight;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final step = widget.steps[_current];
    if (step.fab) {
      final centerX = rtl
          ? _fabMargin + _fabSize / 2
          : media.size.width - _fabMargin - _fabSize / 2;
      final centerY = navTop - _fabMargin - _fabSize / 2;
      return Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: _fabSize + AppSpacing.lg,
        height: _fabSize + AppSpacing.lg,
      );
    }
    final slot = media.size.width / widget.itemCount;
    final visualIndex = rtl
        ? widget.itemCount - 1 - step.tabIndex
        : step.tabIndex;
    final centerX = slot * (visualIndex + 0.5);
    return Rect.fromCenter(
      center: Offset(centerX, navTop + navHeight / 2),
      width: slot * 0.82,
      height: navHeight * 0.92,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final step = widget.steps[_current];
    final rect = _targetRect(context);
    final hole = RRect.fromRectAndRadius(
      rect,
      Radius.circular(step.fab ? rect.height / 2 : AppRadii.card),
    );
    // The plus button sits above the nav bar, so lift the card clear of it.
    final cardBottom = step.fab
        ? media.viewPadding.bottom +
              kBottomNavigationBarHeight +
              _fabMargin +
              _fabSize +
              AppSpacing.md
        : media.viewPadding.bottom + kBottomNavigationBarHeight + AppSpacing.sm;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(hole: hole)),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: cardBottom,
              child: _TourCard(
                step: step,
                index: _current,
                total: widget.steps.length,
                onNext: _next,
                onSkip: widget.onFinish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole});

  final RRect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas
      ..saveLayer(bounds, Paint())
      ..drawRect(bounds, Paint()..color = AppColors.ink.withValues(alpha: 0.66))
      ..drawRRect(hole, Paint()..blendMode = BlendMode.clear)
      ..restore()
      ..drawRRect(
        hole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.white.withValues(alpha: 0.9),
      );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.hole != hole;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLast = index == total - 1;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(step.icon, color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Dots(index: index, total: total),
              const Spacer(),
              if (!isLast)
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    l10n.tourSkip,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                ),
                child: Text(isLast ? l10n.tourDone : l10n.tourNext),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: AppSpacing.xs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? AppColors.ink : AppColors.mist,
            ),
          ),
      ],
    );
  }
}
