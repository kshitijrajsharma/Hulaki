import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/connectivity.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/design/widgets/hot_key_chip.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/auth/application/auth_state.dart';
import 'package:hulaki/features/capture/gps_gate.dart';
import 'package:hulaki/features/capture/presentation/live_gps_strip.dart';
import 'package:hulaki/features/capture/staged_point.dart';
import 'package:hulaki/features/discovery/listing_publisher.dart';
import 'package:hulaki/features/export/geojson.dart';
import 'package:hulaki/features/groups/hot_key_icons.dart';
import 'package:hulaki/features/groups/presentation/group_avatar.dart';
import 'package:hulaki/features/groups/presentation/group_info_screen.dart';
import 'package:hulaki/features/map/map_screen.dart';
import 'package:hulaki/features/messaging/presentation/message_bubble.dart';
import 'package:hulaki/features/messaging/presentation/point_detail_screen.dart';
import 'package:hulaki/features/onboarding/coach_tip.dart';
import 'package:hulaki/features/onboarding/demo_group.dart';
import 'package:hulaki/features/settings/privacy_provider.dart';
import 'package:hulaki/features/sync/presentation/pending_upload_banner.dart';
import 'package:hulaki/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

/// The capture loop: talk, tap a hot-key, send. Every message is a geotagged
/// observation that also lands on the shared map.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    required this.groupId,
    required this.groupName,
    this.stagedPoint,
    super.key,
  });

  final String groupId;
  final String groupName;

  /// A map-tapped location to drop the next send at, instead of the live fix.
  final StagedPoint? stagedPoint;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  String? _selectedTagId;
  bool _sending = false;
  Uint8List? _pendingPhoto;
  StagedPoint? _stagedPoint;

  /// The last non-null compass heading. The magnetometer often reports null
  /// while it settles (especially on iOS), so a fresh read at send time is
  /// frequently empty; holding the last good value keeps the point's heading.
  double? _lastHeading;

  bool _resyncing = false;

  @override
  void initState() {
    super.initState();
    _stagedPoint = widget.stagedPoint;
    unawaited(_catchUpAndRepublish());
  }

  /// Pulls anything published while this thread was closed, then, for an admin
  /// of a public group, republishes the directory listing so its nearby preview
  /// (mapper count included) stays in step with the group.
  Future<void> _catchUpAndRepublish() async {
    await ref.read(syncServiceProvider).catchUp(widget.groupId);
    if (!mounted) return;
    await refreshPublicListing(ref, widget.groupId);
  }

  /// The header subtitle: a live tally of mapped points and contributors.
  String _statsLabel(AppLocalizations l10n, int points, int mappers) {
    if (points == 0) return l10n.threadNoPointsYet;
    return l10n.threadStats(
      l10n.threadPointCount(points),
      l10n.threadMapperCount(mappers),
    );
  }

  /// Fetches the group's full history and reconciles any gap, for the pull to
  /// refresh and the header sync button.
  Future<void> _resync(AppLocalizations l10n) async {
    if (_resyncing) return;
    setState(() => _resyncing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncServiceProvider).resync(widget.groupId);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.threadUpToDate)),
      );
    } finally {
      if (mounted) setState(() => _resyncing = false);
    }
  }

  Future<void> _removeSample() async {
    final navigator = Navigator.of(context);
    await removeSampleGroup(ref.read(databaseProvider), widget.groupId);
    if (mounted) navigator.pop();
  }

  Future<void> _attachPhoto(AppLocalizations l10n) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.threadTakePhoto),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.threadChooseFromGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    // Stage the photo so a caption and hot-key can be added before sending.
    if (mounted) setState(() => _pendingPhoto = bytes);
  }

  Future<void> _messageActions(AppLocalizations l10n, Message message) async {
    final isMine = message.senderId == ref.read(currentUserIdProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (message.body != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(l10n.threadCopyText),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
            if (isMine && message.mediaId == null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.threadEdit),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            if (isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: Text(
                  l10n.threadDelete,
                  style: const TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body ?? ''));
      case 'edit':
        await _editMessage(message);
      case 'delete':
        await ref.read(syncServiceProvider).deleteMessage(message.id);
    }
  }

  /// Opens the group map. If the user taps a spot there to place a point, the
  /// map returns it and the next send drops at that location.
  Future<void> _openMap() async {
    final staged = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) =>
            MapScreen(groupId: widget.groupId, groupName: widget.groupName),
      ),
    );
    if (staged is StagedPoint && mounted) {
      setState(() => _stagedPoint = staged);
    }
  }

  Future<void> _editMessage(Message message) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditMessageDialog(initialText: message.body ?? ''),
    );
    if (result != null && result.trim().isNotEmpty) {
      await ref
          .read(syncServiceProvider)
          .editMessage(messageId: message.id, newBody: result.trim());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Applies the group's moderation rules to a pending send, surfacing the
  /// reason when a point must be refused. A map-placed point from a non-admin
  /// where placement is disallowed, a fix weaker than the accuracy cap, or a
  /// point outside the mapping area when that is off are blocked; an allowed
  /// out-of-area point asks for confirmation first.
  Future<bool> _passesModeration(
    AppLocalizations l10n,
    GeoResult geo, {
    required bool placed,
  }) async {
    final group = await ref.read(databaseProvider).groupById(widget.groupId);
    if (group == null) return true;
    final iAmAdmin = ref.read(isGroupAdminProvider(widget.groupId));

    if (placed && !iAmAdmin && !group.allowMemberPlace) {
      _blockedSnack(l10n.threadPlacementAdminsOnly);
      return false;
    }

    final limit = group.gpsLimitM;
    final accuracy = geo.accuracyM;
    if (limit != null && accuracy != null && accuracy > limit) {
      _blockedSnack(l10n.threadGpsTooWeak(accuracy.round()));
      return false;
    }

    final aoi = group.aoiGeoJson;
    final lat = geo.lat;
    final lng = geo.lng;
    if (aoi != null &&
        lat != null &&
        lng != null &&
        !pointInAoi(aoi, lat, lng)) {
      if (!group.allowOutsideArea) {
        _blockedSnack(l10n.threadOutsideAreaBlocked);
        return false;
      }
      return _confirmOutsideArea(l10n);
    }
    return true;
  }

  void _blockedSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmOutsideArea(AppLocalizations l10n) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.threadOutsideAreaTitle),
        content: Text(l10n.threadOutsideAreaBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.threadCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.threadSendAnyway),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _send(AppLocalizations l10n) async {
    final text = _controller.text.trim();
    final photo = _pendingPhoto;
    if ((text.isEmpty && photo == null && _selectedTagId == null) || _sending) {
      return;
    }
    setState(() => _sending = true);

    try {
      final staged = _stagedPoint;
      final live = ref.read(liveLocationProvider).asData?.value;
      final heading =
          ref.read(compassHeadingProvider).asData?.value ?? _lastHeading;
      final GeoResult geo;
      if (staged != null) {
        geo = GeoResult.placed(staged.lat, staged.lng);
      } else if (live != null) {
        geo = GeoResult.fix(
          GpsFix(
            lat: live.lat,
            lng: live.lng,
            accuracyM: live.accuracyM,
            altitudeM: live.altitudeM,
            headingDeg: heading,
          ),
        );
      } else {
        final fixes = ref.read(gpsSourceProvider).fixes();
        final acquired = await const GpsGate().acquire(fixes);
        geo = acquired.lat == null
            ? acquired
            : GeoResult.fix(
                GpsFix(
                  lat: acquired.lat!,
                  lng: acquired.lng!,
                  accuracyM: acquired.accuracyM!,
                  altitudeM: acquired.altitudeM,
                  headingDeg: heading,
                ),
              );
      }

      if (!await _passesModeration(l10n, geo, placed: staged != null)) {
        return;
      }
      _controller.clear();
      final auth = ref.read(authControllerProvider);
      final anonymous = ref.read(appearAnonymousProvider);
      final senderName = (anonymous || auth is! AuthSignedIn)
          ? null
          : auth.session.username;
      final sync = ref.read(syncServiceProvider);
      if (photo != null) {
        await sync.sendPhoto(
          groupId: widget.groupId,
          bytes: photo,
          caption: text.isEmpty ? null : text,
          tagId: _selectedTagId,
          geo: geo,
          senderName: senderName,
          anonymous: anonymous,
        );
      } else {
        await sync.sendText(
          groupId: widget.groupId,
          text: text.isEmpty ? null : text,
          tagId: _selectedTagId,
          geo: geo,
          senderName: senderName,
          anonymous: anonymous,
        );
      }
      if (mounted) {
        setState(() {
          _pendingPhoto = null;
          _stagedPoint = null;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep the compass alive while the thread is open and remember the last
    // good heading, so a point sent the instant the sensor blips null still
    // carries a direction.
    ref.listen<AsyncValue<double?>>(compassHeadingProvider, (_, next) {
      final heading = next.asData?.value;
      if (heading != null) _lastHeading = heading;
    });
    final l10n = AppLocalizations.of(context);
    final messages = ref.watch(messagesProvider(widget.groupId));
    final hotKeys = ref.watch(hotKeysProvider(widget.groupId)).value ?? [];
    final hotKeysById = {for (final h in hotKeys) h.id: h};
    final me = ref.watch(currentUserIdProvider);
    final isSyncing =
        ref
            .watch(syncingGroupsProvider)
            .asData
            ?.value
            .contains(widget.groupId) ??
        false;
    final names =
        ref.watch(profileNamesProvider).asData?.value ??
        const <String, String>{};
    final anonymous = ref.watch(appearAnonymousProvider);

    final items = messages.asData?.value ?? const <Message>[];
    final live = items.where((m) => m.deletedAt == null);
    final pointCount = live.where((m) => m.lat != null).length;
    final mapperCount = live.map((m) => m.senderId).toSet().length;
    final groups =
        ref.watch(activeGroupsProvider).asData?.value ?? const <Group>[];
    final match = groups.where((g) => g.id == widget.groupId);
    final photo = match.isEmpty ? null : match.first.photo;
    final isSample = match.isNotEmpty && match.first.isSample;

    return Scaffold(
      backgroundColor: AppColors.mist,
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupInfoScreen(groupId: widget.groupId),
            ),
          ),
          child: Row(
            children: [
              GroupAvatar(photo: photo, size: 34, radius: 10),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.groupName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _statsLabel(l10n, pointCount, mapperCount),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.threadRefreshTooltip,
            icon: _resyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _resyncing ? null : () => unawaited(_resync(l10n)),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: _openMap,
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: LiveGpsStrip(),
          ),
          PendingUploadBanner(groupId: widget.groupId),
          if (isSample)
            _SampleBanner(onRemove: () => unawaited(_removeSample()))
          else ...[
            CoachTip(
              tipKey: 'thread',
              message: l10n.threadCoachTapTag,
            ),
            CoachTip(
              tipKey: 'thread-sync',
              message: l10n.threadCoachPullToRefresh,
            ),
          ],
          Expanded(
            child: Stack(
              children: [
                if (anonymous)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Icon(
                          Icons.person_off_outlined,
                          size: 140,
                          color: AppColors.ink.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                  ),
                messages.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        l10n.threadLoadError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  data: (items) => items.isEmpty && isSyncing
                      ? const Center(child: _SyncingHint())
                      : RefreshIndicator(
                          onRefresh: () => _resync(l10n),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final message = items[i];
                              final tag = message.tagId == null
                                  ? null
                                  : hotKeysById[message.tagId];
                              final tagColor = tag == null
                                  ? null
                                  : Color(tag.colorValue);
                              return GestureDetector(
                                onLongPress: () =>
                                    _messageActions(l10n, message),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PointDetailScreen(
                                      groupId: widget.groupId,
                                      message: message,
                                      tagLabel: tag?.label,
                                      tagColor: tagColor,
                                      tagIcon: tag?.iconName,
                                      mediaResolver: ref
                                          .read(databaseProvider)
                                          .mediaBytes,
                                    ),
                                  ),
                                ),
                                child: MessageBubble(
                                  message: message,
                                  isMine: message.senderId == me,
                                  anonymous: message.anonymous,
                                  senderName:
                                      names[message.senderId] ??
                                      l10n.threadMemberFallback,
                                  tagLabel: tag?.label,
                                  tagColor: tagColor,
                                  tagIcon: hotKeyIcon(tag?.iconName),
                                  mediaResolver: ref
                                      .read(databaseProvider)
                                      .mediaBytes,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (_stagedPoint != null)
            _StagedPointBanner(
              onClear: () => setState(() => _stagedPoint = null),
            ),
          if (anonymous) const _AnonymousBar(),
          _HotKeyBar(
            hotKeys: hotKeys,
            selectedId: _selectedTagId,
            onSelect: (id) => setState(
              () => _selectedTagId = _selectedTagId == id ? null : id,
            ),
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            attachment: _pendingPhoto,
            onSend: () => _send(l10n),
            onAttach: () => _attachPhoto(l10n),
            onRemoveAttachment: () => setState(() => _pendingPhoto = null),
          ),
        ],
      ),
    );
  }
}

/// Edit dialog that owns its text controller so it is disposed only after the
/// field has fully unmounted, avoiding a use-after-dispose on focus release.
class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.threadEditMessageTitle),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.threadCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.threadSave),
        ),
      ],
    );
  }
}

/// Sits above the composer while anonymous mode is on, so it is clear before
/// sending that this message will carry no name.
class _AnonymousBar extends StatelessWidget {
  const _AnonymousBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.ink.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            AppLocalizations.of(context).threadAnonymousNotice,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sits above the composer while a map-tapped location is pending, showing
/// where the next send will land and offering to clear it.
class _StagedPointBanner extends StatelessWidget {
  const _StagedPointBanner({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.sm, 8),
      child: Row(
        children: [
          const Icon(
            Icons.add_location_alt_outlined,
            size: 16,
            color: AppColors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).threadStagedPointBanner,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotKeyBar extends StatelessWidget {
  const _HotKeyBar({
    required this.hotKeys,
    required this.selectedId,
    required this.onSelect,
  });

  final List<HotKey> hotKeys;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (hotKeys.isEmpty) return const SizedBox.shrink();
    final showMore = hotKeys.length > 6;
    final tagList = SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hotKeys.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final hotKey = hotKeys[i];
          return HotKeyChip(
            label: hotKey.label,
            color: Color(hotKey.colorValue),
            icon: hotKeyIcon(hotKey.iconName),
            selected: hotKey.id == selectedId,
            onTap: () => onSelect(hotKey.id),
          );
        },
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      // With many tags, the row keeps to one line and a grid button pinned at
      // the end opens the full set, so nothing sits in a bar above the tags.
      child: showMore
          ? Row(
              children: [
                Expanded(child: tagList),
                const SizedBox(width: 8),
                _MoreTagsButton(onTap: () => unawaited(_pickTag(context))),
              ],
            )
          : tagList,
    );
  }

  Future<void> _pickTag(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagPickerSheet(
        hotKeys: hotKeys,
        selectedId: selectedId,
        onSelect: onSelect,
      ),
    );
  }
}

/// A compact grid button pinned at the end of the tag row when there are many
/// tags. Tapping it opens the full set of tags as a grid.
class _MoreTagsButton extends StatelessWidget {
  const _MoreTagsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mist,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.grid_view_rounded,
            size: 18,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// The full tag list as a drawer for picking one to tag the next message.
class _TagPickerSheet extends StatelessWidget {
  const _TagPickerSheet({
    required this.hotKeys,
    required this.selectedId,
    required this.onSelect,
  });

  final List<HotKey> hotKeys;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context).threadTagTheNextPoint,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final hotKey in hotKeys)
                      HotKeyChip(
                        label: hotKey.label,
                        color: Color(hotKey.colorValue),
                        icon: hotKeyIcon(hotKey.iconName),
                        selected: hotKey.id == selectedId,
                        onTap: () {
                          onSelect(hotKey.id);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SyncingHint extends StatelessWidget {
  const _SyncingHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppLocalizations.of(context).threadLoadingMessages,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.attachment,
    required this.onSend,
    required this.onAttach,
    required this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final bool sending;
  final Uint8List? attachment;
  final Future<void> Function() onSend;
  final Future<void> Function() onAttach;
  final VoidCallback onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = attachment;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        photo,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.threadPhotoReady,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: onRemoveAttachment,
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.textMuted),
                  onPressed: onAttach,
                ),
                Expanded(
                  child: TextField(
                    key: const Key('composer-field'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.threadComposerHint,
                      filled: true,
                      fillColor: AppColors.field,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: sending ? null : onSend,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: AppColors.white,
                            size: 19,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A short instructional card shown at the top of the seeded sample group: what
/// it is, what to try, and a one-tap way to remove it once done.
class _SampleBanner extends StatelessWidget {
  const _SampleBanner({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_outlined,
                size: 18,
                color: AppColors.amber,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.demoBannerTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.demoBannerBody,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRemove,
              child: Text(l10n.demoBannerRemove),
            ),
          ),
        ],
      ),
    );
  }
}
