import 'dart:async';

import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/map/navigate_sheet.dart';
import 'package:flutter/material.dart';

/// Sheet for a tap on an empty map spot: place a point here (staged into the
/// composer) or hand the spot to an external navigation app. Returns true when
/// the user chose to add an observation. When [canPlace] is false the add
/// action is withheld, so only navigation is offered.
Future<bool> showMapTapSheet({
  required BuildContext context,
  required double lat,
  required double lng,
  bool canPlace = true,
}) async {
  final chose = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Drop a point here',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (!canPlace) ...[
              const SizedBox(height: 6),
              const Text(
                'Only admins can place points in this group. Send your live '
                'GPS point from the chat instead.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop(false);
                      unawaited(
                        showNavigateSheet(context: context, lat: lat, lng: lng),
                      );
                    },
                    icon: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Navigate here'),
                  ),
                ),
                if (canPlace) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 16,
                      ),
                      label: const Text('Add here'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return chose ?? false;
}
