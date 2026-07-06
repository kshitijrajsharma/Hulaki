import 'dart:async';
import 'dart:convert';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/hot_key_chip.dart';
import 'package:fieldchat/design/widgets/primary_button.dart';
import 'package:fieldchat/features/discovery/area_minimap.dart';
import 'package:fieldchat/features/discovery/place_line.dart';
import 'package:fieldchat/features/discovery/public_directory.dart';
import 'package:fieldchat/features/groups/hot_key_icons.dart';
import 'package:fieldchat/features/groups/presentation/group_avatar.dart';
import 'package:fieldchat/features/messaging/presentation/chat_thread_screen.dart';
import 'package:fieldchat/features/settings/units_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// A public group as seen before joining: name, where it is, how far, and what
/// it maps. Reached by tapping a group in the nearby list.
class GroupPreviewScreen extends ConsumerStatefulWidget {
  const GroupPreviewScreen({required this.group, super.key});

  final PublicGroup group;

  @override
  ConsumerState<GroupPreviewScreen> createState() => _GroupPreviewScreenState();
}

enum _RequestState { none, requesting, pending, joining }

class _GroupPreviewScreenState extends ConsumerState<GroupPreviewScreen> {
  bool _joining = false;
  _RequestState _request = _RequestState.none;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (widget.group.joinApproval) unawaited(_checkExistingRequest());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Instant join for an open group: the key is in the invite link.
  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      final joined = await ref
          .read(groupServiceProvider)
          .joinViaLink(widget.group.inviteUrl, identity);
      await _openThread(joined.id, joined.name);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _checkExistingRequest() async {
    final me = ref.read(currentUserIdProvider);
    final existing = await ref
        .read(publicDirectoryProvider)
        .myRequest(widget.group.groupId, me);
    if (existing == null || !mounted) return;
    if (existing.sealedKey != null) {
      await _completeApprovedJoin(existing.sealedKey!);
    } else {
      setState(() => _request = _RequestState.pending);
      _startPolling();
    }
  }

  /// Files a signed request to join an approval-gated group.
  Future<void> _requestToJoin() async {
    if (_request != _RequestState.none) return;
    setState(() => _request = _RequestState.requesting);
    final me = ref.read(currentUserIdProvider);
    final identity = await ref.read(deviceIdentityProvider.future);
    final self = await ref.read(databaseProvider).profileById(me);
    await ref
        .read(publicDirectoryProvider)
        .requestJoin(
          JoinRequest(
            id: const Uuid().v4(),
            groupId: widget.group.groupId,
            requesterId: me,
            requesterName: self?.displayName,
            signingKey: base64Encode(identity.signingPublic),
            agreementKey: base64Encode(identity.agreementPublic),
          ),
        );
    if (!mounted) return;
    setState(() => _request = _RequestState.pending);
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_pollApproval()),
    );
  }

  Future<void> _pollApproval() async {
    final me = ref.read(currentUserIdProvider);
    final request = await ref
        .read(publicDirectoryProvider)
        .myRequest(widget.group.groupId, me);
    final sealed = request?.sealedKey;
    if (sealed != null) {
      _poll?.cancel();
      await _completeApprovedJoin(sealed);
    }
  }

  /// Unwraps the sealed group key an admin delivered, then joins for real.
  Future<void> _completeApprovedJoin(String sealedKey) async {
    if (_request == _RequestState.joining) return;
    if (mounted) setState(() => _request = _RequestState.joining);
    final identity = await ref.read(deviceIdentityProvider.future);
    final sealed = (jsonDecode(sealedKey) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    final groupKey = await identity.open(sealed);
    final joined = await ref
        .read(groupServiceProvider)
        .joinWithKey(widget.group.groupId, base64Encode(groupKey), identity);
    await _openThread(joined.id, joined.name);
  }

  Future<void> _openThread(String groupId, String name) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(groupId: groupId, groupName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final units = ref.watch(unitsProvider);
    final description = group.description;
    final aoi = group.aoiGeoJson;

    return Scaffold(
      appBar: AppBar(title: const Text('Group')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Center(
                    child: GroupAvatar(
                      photo: group.photo,
                      size: 88,
                      radius: 24,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    group.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: GroupPlaceLine(group: group, units: units),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: Text(
                      _mapperLine(group.mapperCount),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (group.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tag in group.tags)
                          HotKeyChip(
                            label: tag.label,
                            color: Color(tag.colorValue),
                            icon: hotKeyIcon(tag.iconName),
                          ),
                      ],
                    ),
                  ],
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                  if (aoi != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: SizedBox(
                        height: 180,
                        child: AreaMiniMap(aoiGeoJson: aoi),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: group.joinApproval ? _approvalButton() : _openButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _openButton() => PrimaryButton(
    label: _joining ? 'Joining…' : 'Join group',
    onPressed: _joining ? null : () => unawaited(_join()),
  );

  Widget _approvalButton() {
    switch (_request) {
      case _RequestState.none:
        return PrimaryButton(
          label: 'Request to join',
          onPressed: () => unawaited(_requestToJoin()),
        );
      case _RequestState.requesting:
        return const PrimaryButton(label: 'Requesting…');
      case _RequestState.pending:
        return const PrimaryButton(label: 'Waiting for approval…');
      case _RequestState.joining:
        return const PrimaryButton(label: 'Joining…');
    }
  }

  String _mapperLine(int count) {
    if (count <= 0) return 'No mappers yet';
    return count == 1 ? '1 mapper' : '$count mappers';
  }
}
