import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/hot_key_chip.dart';
import 'package:hulaki/design/widgets/primary_button.dart';
import 'package:hulaki/features/discovery/area_minimap.dart';
import 'package:hulaki/features/discovery/place_line.dart';
import 'package:hulaki/features/discovery/public_directory.dart';
import 'package:hulaki/features/groups/hot_key_icons.dart';
import 'package:hulaki/features/groups/presentation/group_avatar.dart';
import 'package:hulaki/features/messaging/presentation/chat_thread_screen.dart';
import 'package:hulaki/features/settings/units_provider.dart';
import 'package:hulaki/l10n/app_localizations.dart';
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
  bool _alreadyMember = false;
  _RequestState _request = _RequestState.none;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  /// A group already in the local store is one this device created or joined,
  /// so it opens directly instead of offering to join or request.
  Future<void> _init() async {
    final existing = await ref
        .read(databaseProvider)
        .groupById(widget.group.groupId);
    if (existing != null) {
      if (mounted) setState(() => _alreadyMember = true);
      return;
    }
    if (widget.group.joinApproval) await _checkExistingRequest();
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
    final l10n = AppLocalizations.of(context);
    final group = widget.group;
    final units = ref.watch(unitsProvider);
    final description = group.description;
    final aoi = group.aoiGeoJson;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoverGroupTitle)),
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
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: GroupPlaceLine(group: group, units: units),
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
              child: _alreadyMember
                  ? _memberButton(l10n)
                  : (group.joinApproval
                        ? _approvalButton(l10n)
                        : _openButton(l10n)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _openButton(AppLocalizations l10n) => PrimaryButton(
    label: _joining ? l10n.discoverJoining : l10n.discoverJoinGroup,
    loading: _joining,
    onPressed: _joining ? null : () => unawaited(_join()),
  );

  /// Shown for a group this device already belongs to, including your own.
  Widget _memberButton(AppLocalizations l10n) => PrimaryButton(
    label: l10n.discoverOpen,
    onPressed: () =>
        unawaited(_openThread(widget.group.groupId, widget.group.name)),
  );

  Widget _approvalButton(AppLocalizations l10n) {
    switch (_request) {
      case _RequestState.none:
        return PrimaryButton(
          label: l10n.discoverRequestToJoin,
          onPressed: () => unawaited(_requestToJoin()),
        );
      case _RequestState.requesting:
        return PrimaryButton(label: l10n.discoverRequesting, loading: true);
      case _RequestState.pending:
        return PrimaryButton(label: l10n.discoverRequestSent);
      case _RequestState.joining:
        return PrimaryButton(label: l10n.discoverJoining, loading: true);
    }
  }
}
