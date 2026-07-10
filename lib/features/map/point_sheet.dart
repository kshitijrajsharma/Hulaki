import 'dart:async';

import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/groups/hot_key_icons.dart';
import 'package:fieldchat/features/map/navigate_sheet.dart';
import 'package:fieldchat/features/messaging/presentation/point_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef MediaResolver = Future<Uint8List?> Function(String mediaId);

/// A quick callout for a tapped map point: what it is, where, and the actions
/// to open it in chat, navigate to it, copy its coordinates, or see it in full.
Future<void> showPointSheet({
  required BuildContext context,
  required Message message,
  required HotKey? tag,
  required MediaResolver mediaResolver,
}) {
  final tagColor = tag == null ? null : Color(tag.colorValue);
  final mediaId = message.mediaId;
  // Resolve the photo once here, not inside the builder, so sheet rebuilds
  // reuse the same future instead of reloading and flickering.
  final mediaFuture = mediaId == null ? null : mediaResolver(mediaId);
  return showModalBottomSheet<void>(
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
            if (mediaFuture != null)
              FutureBuilder<Uint8List?>(
                future: mediaFuture,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        bytes,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  );
                },
              ),
            if (tag != null)
              _TagChip(label: tag.label, color: tagColor!, icon: tag.iconName),
            if (message.body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message.body!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: message.locationPending
                  ? null
                  : () => unawaited(_copyCoords(context, message)),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message.locationPending
                        ? 'Location pending'
                        : '${message.lat?.toStringAsFixed(5)}, '
                              '${message.lng?.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (!message.locationPending) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.copy,
                      size: 13,
                      color: AppColors.textFaint,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(Navigator.of(context).maybePop());
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('In chat'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: message.locationPending
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            unawaited(
                              showNavigateSheet(
                                context: context,
                                lat: message.lat!,
                                lng: message.lng!,
                                label: message.body,
                              ),
                            );
                          },
                    icon: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Navigate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PointDetailScreen(
                        groupId: message.groupId,
                        message: message,
                        tagLabel: tag?.label,
                        tagColor: tagColor,
                        tagIcon: tag?.iconName,
                        mediaResolver: mediaResolver,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_full, size: 15),
              label: const Text('Full detail'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _copyCoords(BuildContext context, Message message) async {
  await Clipboard.setData(
    ClipboardData(text: '${message.lat}, ${message.lng}'),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coordinates copied')),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final glyph = hotKeyIcon(icon);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 13, color: AppColors.white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
