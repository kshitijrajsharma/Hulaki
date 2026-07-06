import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/design/widgets/gps_strip.dart';
import 'package:fieldchat/features/capture/presentation/gps_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The GPS strip wired to the live device location. Shows real accuracy and an
/// acquiring state until the first fix arrives. Subscribing here is what
/// prompts for location permission on entering a screen. Tapping opens the
/// detail sheet.
class LiveGpsStrip extends ConsumerWidget {
  const LiveGpsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(liveLocationProvider).asData?.value;
    return GpsStrip(
      accuracyMeters: location?.accuracyM,
      onTap: () => showGpsDetailSheet(context),
    );
  }
}
