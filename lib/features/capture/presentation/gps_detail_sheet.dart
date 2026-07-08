import 'dart:async';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/capture/utm.dart';
import 'package:fieldchat/features/settings/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showGpsDetailSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _GpsDetailSheet(),
  );
}

class _GpsDetailSheet extends ConsumerStatefulWidget {
  const _GpsDetailSheet();

  @override
  ConsumerState<_GpsDetailSheet> createState() => _GpsDetailSheetState();
}

class _GpsDetailSheetState extends ConsumerState<_GpsDetailSheet>
    with SingleTickerProviderStateMixin {
  bool _showUtm = false;

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

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveLocationProvider, (_, next) {
      if (next.asData?.value != null) {
        unawaited(_pulse.forward(from: 0));
      }
    });
    final location = ref.watch(liveLocationProvider).asData?.value;
    final heading = ref.watch(compassHeadingProvider).asData?.value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('GPS detail', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (location == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text('Locating GPS…'),
                  ],
                ),
              )
            else ...[
              _QualityBanner(accuracyM: location.accuracyM, pulse: _beat),
              const SizedBox(height: AppSpacing.lg),
              _CoordinateBlock(
                showUtm: _showUtm,
                lat: location.lat,
                lng: location.lng,
                onToggle: (value) => setState(() => _showUtm = value),
              ),
              const SizedBox(height: AppSpacing.md),
              _MetricRow(
                label: 'Altitude',
                value: _metersOrDash(location.altitudeM),
              ),
              _MetricRow(
                label: 'Heading',
                value: _heading(heading),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _metersOrDash(double? meters) =>
      meters == null ? '-' : '${meters.toStringAsFixed(0)} m';

  String _heading(double? degrees) {
    if (degrees == null) return '-';
    final normalized = (degrees % 360 + 360) % 360;
    return '${normalized.round()}° ${cardinalFor(normalized)}';
  }
}

class _QualityBanner extends StatelessWidget {
  const _QualityBanner({required this.accuracyM, required this.pulse});

  final double accuracyM;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final strong = accuracyM <= 15;
    final tone = strong ? AppColors.gpsStrong : AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: pulse,
            child: Icon(
              strong ? Icons.gps_fixed : Icons.gps_not_fixed,
              size: 18,
              color: tone,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            strong ? 'Strong fix' : 'Weak fix',
            style: TextStyle(fontWeight: FontWeight.w700, color: tone),
          ),
          const Spacer(),
          Text(
            '±${accuracyM.round()} m',
            style: TextStyle(fontWeight: FontWeight.w700, color: tone),
          ),
        ],
      ),
    );
  }
}

class _CoordinateBlock extends StatelessWidget {
  const _CoordinateBlock({
    required this.showUtm,
    required this.lat,
    required this.lng,
    required this.onToggle,
  });

  final bool showUtm;
  final double lat;
  final double lng;
  final ValueChanged<bool> onToggle;

  String get _value => showUtm
      ? latLonToUtm(lat, lng).label
      : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'COORDINATES',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            _FormatToggle(showUtm: showUtm, onToggle: onToggle),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                _value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: _value)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coordinates copied')),
                );
              },
            ),
          ],
        ),
        if (showUtm)
          Text(
            'UTM zone ${latLonToUtm(lat, lng).zone}'
            '${latLonToUtm(lat, lng).hemisphere}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({required this.showUtm, required this.onToggle});

  final bool showUtm;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          _Segment(
            label: 'Lat/Lon',
            selected: !showUtm,
            onTap: () => onToggle(false),
          ),
          _Segment(
            label: 'UTM',
            selected: showUtm,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.ink : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
