import 'dart:async';

import 'package:fieldchat/app/connectivity.dart';
import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/hot_key_chip.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/auth/application/auth_state.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';
import 'package:fieldchat/features/capture/presentation/live_gps_strip.dart';
import 'package:fieldchat/features/capture/staged_point.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/groups/hot_key_icons.dart';
import 'package:fieldchat/features/groups/presentation/group_avatar.dart';
import 'package:fieldchat/features/groups/presentation/group_info_screen.dart';
import 'package:fieldchat/features/map/map_screen.dart';
import 'package:fieldchat/features/messaging/presentation/message_bubble.dart';
import 'package:fieldchat/features/messaging/presentation/point_detail_screen.dart';
import 'package:fieldchat/features/onboarding/coach_tip.dart';
import 'package:fieldchat/features/settings/privacy_provider.dart';
import 'package:fieldchat/features/sync/presentation/pending_upload_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  bool _resyncing = false;

  @override
  void initState() {
    super.initState();
    _stagedPoint = widget.stagedPoint;
    // Pull anything published while this thread was closed, on open.
    unawaited(ref.read(syncServiceProvider).catchUp(widget.groupId));
  }

  /// The header subtitle: a live tally of mapped points and contributors.
  String _statsLabel(int points, int mappers) {
    if (points == 0) return 'No points yet';
    final pointText = points == 1 ? '1 point' : '$points points';
    final peopleText = mappers == 1 ? '1 person' : '$mappers people';
    return '$pointText · $peopleText';
  }

  /// Fetches the group's full history and reconciles any gap, for the pull to
  /// refresh and the header sync button.
  Future<void> _resync() async {
    if (_resyncing) return;
    setState(() => _resyncing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncServiceProvider).resync(widget.groupId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Up to date')),
      );
    } finally {
      if (mounted) setState(() => _resyncing = false);
    }
  }

  Future<void> _attachPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
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

  Future<void> _messageActions(Message message) async {
    final isMine = message.senderId == ref.read(currentUserIdProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (message.body != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy text'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
            if (isMine && message.mediaId == null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            if (isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.danger),
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
  Future<bool> _passesModeration(GeoResult geo, {required bool placed}) async {
    final group = await ref.read(databaseProvider).groupById(widget.groupId);
    if (group == null) return true;
    final iAmAdmin = ref.read(isGroupAdminProvider(widget.groupId));

    if (placed && !iAmAdmin && !group.allowMemberPlace) {
      _blockedSnack(
        'Only admins can place points on the map here. Send your live '
        'GPS point instead.',
      );
      return false;
    }

    final limit = group.gpsLimitM;
    final accuracy = geo.accuracyM;
    if (limit != null && accuracy != null && accuracy > limit) {
      _blockedSnack(
        'GPS is only accurate to ±${accuracy.round()} m right now. Move to '
        'open sky and try again.',
      );
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
        _blockedSnack('This point is outside the mapping area.');
        return false;
      }
      return _confirmOutsideArea();
    }
    return true;
  }

  void _blockedSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmOutsideArea() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Outside the mapping area'),
        content: const Text(
          'This point is outside the group mapping area. Send it anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final photo = _pendingPhoto;
    if ((text.isEmpty && photo == null && _selectedTagId == null) || _sending) {
      return;
    }
    setState(() => _sending = true);

    try {
      final staged = _stagedPoint;
      final live = ref.read(liveLocationProvider).asData?.value;
      final heading = ref.read(compassHeadingProvider).asData?.value;
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

      if (!await _passesModeration(geo, placed: staged != null)) {
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
                      _statsLabel(pointCount, mapperCount),
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
            tooltip: 'Refresh this group',
            icon: _resyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _resyncing ? null : _resync,
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
          const CoachTip(
            tipKey: 'thread',
            message: 'Tap a tag, then Send to drop a mapped point here.',
          ),
          const CoachTip(
            tipKey: 'thread-sync',
            message: 'Not seeing older points? Pull down to refresh.',
          ),
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
                  error: (error, _) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Could not load this group. Check your connection '
                        'and pull down to try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  data: (items) => items.isEmpty && isSyncing
                      ? const Center(child: _SyncingHint())
                      : RefreshIndicator(
                          onRefresh: _resync,
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
                                onLongPress: () => _messageActions(message),
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
                                      names[message.senderId] ?? 'Member',
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
            onSend: _send,
            onAttach: _attachPhoto,
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
    return AlertDialog(
      title: const Text('Edit message'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 14,
            color: AppColors.textMuted,
          ),
          SizedBox(width: 6),
          Text(
            "You're anonymous. Teammates won't see your name.",
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
          const Expanded(
            child: Text(
              'Your next message drops a point at this map spot',
              style: TextStyle(
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
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMore) ...[
            _MoreTagsPill(onTap: () => unawaited(_pickTag(context))),
            const SizedBox(height: 6),
          ],
          SizedBox(
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
          ),
        ],
      ),
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

/// The small pill that floats above the tag row when there are many tags.
class _MoreTagsPill extends StatelessWidget {
  const _MoreTagsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Icon(
            Icons.keyboard_arrow_up,
            size: 20,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tag the next point',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final hotKey in hotKeys)
                    ListTile(
                      onTap: () {
                        onSelect(hotKey.id);
                        Navigator.of(context).pop();
                      },
                      leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: Color(hotKey.colorValue),
                        child: hotKeyIcon(hotKey.iconName) == null
                            ? null
                            : Icon(
                                hotKeyIcon(hotKey.iconName),
                                size: 15,
                                color: AppColors.white,
                              ),
                      ),
                      title: Text(
                        hotKey.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: hotKey.id == selectedId
                          ? const Icon(Icons.check, color: AppColors.ink)
                          : null,
                    ),
                ],
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
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Loading messages…',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
                    const Expanded(
                      child: Text(
                        'Photo ready. Add a note and tap a tag, then send.',
                        style: TextStyle(
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
                      hintText: 'Message',
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
