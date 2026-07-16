import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/features/zones/domain/zone.dart';
import 'package:hulaki/features/zones/domain/zone_bucketing.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// The sheet where a member picks their zone. Doubles as the nudge: it shows
/// aggregate counts and headcount only, never who is where. Returns once the
/// pick is made or dismissed.
Future<void> showZonePickerSheet(
  BuildContext context,
  String groupId,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppColors.paper,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
  ),
  builder: (_) => _ZonePickerSheet(groupId: groupId),
);

class _ZonePickerSheet extends ConsumerWidget {
  const _ZonePickerSheet({required this.groupId});

  final String groupId;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    String? zoneId,
  ) async {
    await ref.read(groupServiceProvider).assignMyZone(groupId, zoneId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final zones = ref.watch(zonesProvider(groupId)).asData?.value ?? const [];
    final assigned = ref.watch(myAssignedZoneProvider(groupId));
    final members =
        ref.watch(groupMembersProvider(groupId)).asData?.value ?? const [];
    final messages =
        ref.watch(messagesProvider(groupId)).asData?.value ?? const [];
    final counts = countsByZone(zones, [
      for (final m in messages)
        if (m.lat != null && m.lng != null) (lat: m.lat!, lng: m.lng!),
    ]);

    int mappers(String zoneId) =>
        members.where((m) => m.assignedZoneId == zoneId).length;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.zonePickTitle, style: theme(context).titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.zonePickSubtitle, style: theme(context).bodyMedium),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: zones.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final zone = zones[i];
                    return _ZoneRow(
                      zone: zone,
                      selected: zone.id == assigned?.id,
                      points: counts[zone.id] ?? 0,
                      mappers: mappers(zone.id),
                      onJoin: () => _pick(context, ref, zone.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => assigned == null
                    ? Navigator.of(context).pop()
                    : _pick(context, ref, null),
                child: Text(
                  assigned == null ? l10n.zoneMapAnywhere : l10n.zoneLeave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextTheme theme(BuildContext context) => Theme.of(context).textTheme;
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.selected,
    required this.points,
    required this.mappers,
    required this.onJoin,
  });

  final Zone zone;
  final bool selected;
  final int points;
  final int mappers;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: selected ? AppColors.ink : AppColors.mist,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(zone.colorValue),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${l10n.zonePoints(points)} · $mappers',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Text(
                l10n.zonePickCurrent,
                style: Theme.of(context).textTheme.labelMedium,
              )
            else
              FilledButton(onPressed: onJoin, child: Text(l10n.zonePickJoin)),
          ],
        ),
      ),
    );
  }
}
