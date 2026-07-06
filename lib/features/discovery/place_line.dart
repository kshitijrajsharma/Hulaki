import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/features/discovery/public_directory.dart';
import 'package:fieldchat/features/discovery/reverse_geocode.dart';
import 'package:fieldchat/features/settings/units.dart';
import 'package:flutter/material.dart';

/// The place name (reverse geocoded) and distance for a nearby group, e.g.
/// "Kathmandu · 1 m away". Shows distance alone until the name resolves, and
/// distance only when the device cannot geocode the point.
class GroupPlaceLine extends StatelessWidget {
  const GroupPlaceLine({required this.group, required this.units, super.key});

  final PublicGroup group;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final distance = group.distanceM == null
        ? null
        : '${formatDistance(group.distanceM!, units)} away';
    return FutureBuilder<String?>(
      future: ReverseGeocoder.placeName(group.centerLat, group.centerLng),
      builder: (context, snapshot) {
        final place = snapshot.data;
        final text = [?place, ?distance].join(' · ');
        if (text.isEmpty) return const SizedBox.shrink();
        return Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        );
      },
    );
  }
}
