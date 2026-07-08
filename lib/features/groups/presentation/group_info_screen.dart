import 'dart:async';
import 'dart:convert';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/core/image_thumbnail.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/discovery/public_directory.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/groups/group_member_view.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/groups/presentation/export_sheet.dart';
import 'package:fieldchat/features/groups/presentation/group_avatar.dart';
import 'package:fieldchat/features/groups/presentation/hot_key_editor_screen.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/map/offline_areas.dart';
import 'package:fieldchat/features/map/offline_downloads.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Manage a group after setup: its cover photo, invite link, hot-keys, area,
/// offline tiles, and export.
class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  final _picker = ImagePicker();
  late Future<Group?> _groupFuture = _loadGroup();
  bool _caching = false;

  Future<Group?> _loadGroup() =>
      ref.read(databaseProvider).groupById(widget.groupId);

  void _reload() {
    setState(() {
      _groupFuture = _loadGroup();
    });
  }

  Future<void> _editPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = squareJpegThumbnail(await file.readAsBytes());
    await ref
        .read(groupServiceProvider)
        .updateGroupPhoto(widget.groupId, bytes);
    _reload();
  }

  Future<void> _makeOffline(Group group) async {
    if (_caching) return;
    setState(() => _caching = true);
    try {
      final bounds = await groupBounds(
        ref.read(databaseProvider),
        group.id,
      );
      if (bounds == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draw an area or add points first'),
            ),
          );
        }
        return;
      }
      await ref
          .read(offlineDownloadsProvider.notifier)
          .start(groupId: group.id, groupName: group.name, bounds: bounds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Area saved for offline use')),
        );
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline download failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _caching = false);
    }
  }

  /// Toggles join approval and, for a public group, republishes the directory
  /// listing so it withholds or restores the key to match.
  Future<void> _setJoinApproval(String groupId, bool value) async {
    await ref.read(groupServiceProvider).setJoinApproval(groupId, value: value);
    final group = await ref.read(databaseProvider).groupById(groupId);
    if (group != null && group.isPublic) {
      final center = await _groupCenter(groupId, group.aoiGeoJson);
      if (center != null) await _publishToDirectory(group, center);
    }
    _reload();
  }

  Future<void> _setAllowMemberExport(String groupId, bool value) async {
    await ref
        .read(groupServiceProvider)
        .setAllowMemberExport(groupId, value: value);
    _reload();
  }

  Future<void> _setAllowMemberPlace(String groupId, bool value) async {
    await ref
        .read(groupServiceProvider)
        .setAllowMemberPlace(groupId, value: value);
    _reload();
  }

  Future<void> _setAllowOutsideArea(String groupId, bool value) async {
    await ref
        .read(groupServiceProvider)
        .setAllowOutsideArea(groupId, value: value);
    _reload();
  }

  /// Picks the accuracy cap for sent points. Off clears it; the presets bound
  /// the metres a fix may carry before a send is refused.
  Future<void> _editGpsLimit(String groupId, int? current) async {
    const presets = <int?>[null, 10, 20, 50];
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('GPS accuracy limit'),
        children: [
          for (final preset in presets)
            ListTile(
              title: Text(preset == null ? 'Off' : 'Within ±$preset m'),
              trailing: (current ?? 0) == (preset ?? 0)
                  ? const Icon(Icons.check, color: AppColors.ink)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(preset ?? 0),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref
        .read(groupServiceProvider)
        .setGpsLimit(groupId, chosen == 0 ? null : chosen);
    _reload();
  }

  Future<void> _acceptAdmin(String groupId) async {
    final messenger = ScaffoldMessenger.of(context);
    final identity = await ref.read(deviceIdentityProvider.future);
    await ref.read(groupServiceProvider).acceptAdmin(groupId, identity);
    messenger.showSnackBar(
      const SnackBar(content: Text('You are now an admin of this group')),
    );
  }

  Future<void> _setPublic(String groupId, bool value) async {
    final directory = ref.read(publicDirectoryProvider);
    if (!value) {
      await ref.read(groupServiceProvider).setPublic(groupId, isPublic: false);
      await directory.remove(groupId);
      _reload();
      return;
    }
    final db = ref.read(databaseProvider);
    final group = await db.groupById(groupId);
    final center = await _groupCenter(groupId, group?.aoiGeoJson);
    if (center == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draw an area or add points before going public'),
          ),
        );
      }
      return;
    }
    await ref.read(groupServiceProvider).setPublic(groupId, isPublic: true);
    await _publishToDirectory(group!, center);
    _reload();
  }

  /// Writes the group's public listing (name, description, centre) to the
  /// directory. Called when going public and again when the description changes
  /// while public, so the nearby list stays current.
  Future<void> _publishToDirectory(Group group, (double, double) center) async {
    final db = ref.read(databaseProvider);
    final hotKeys = await db.hotKeysFor(group.id);
    final messages = await db.messagesFor(group.id);
    final mapperCount = messages
        .where((m) => m.lat != null && m.lng != null && m.deletedAt == null)
        .map((m) => m.senderId)
        .toSet()
        .length;
    final photo = group.photo;
    await ref
        .read(publicDirectoryProvider)
        .publish(
          PublicGroup(
            groupId: group.id,
            name: group.name,
            description: group.description,
            centerLat: center.$1,
            centerLng: center.$2,
            // Approval-gated groups withhold the key so joining requires an
            // admin to seal it back to the approved requester.
            encKey: group.joinApproval ? '' : group.encKey,
            joinApproval: group.joinApproval,
            photo: photo == null
                ? null
                : squareJpegThumbnail(photo, size: 256, quality: 75),
            tags: [
              for (final hotKey in hotKeys)
                DirectoryTag(
                  label: hotKey.label,
                  colorValue: hotKey.colorValue,
                  iconName: hotKey.iconName,
                ),
            ],
            mapperCount: mapperCount,
            aoiGeoJson: group.aoiGeoJson,
          ),
        );
  }

  /// The group's map centre: the area's midpoint, else the average of its
  /// points. Null when the group has neither, so it cannot be located.
  Future<(double, double)?> _groupCenter(
    String groupId,
    String? aoiGeoJson,
  ) async {
    final bounds = aoiBounds(aoiGeoJson);
    if (bounds != null) {
      return ((bounds[1] + bounds[3]) / 2, (bounds[0] + bounds[2]) / 2);
    }
    final messages = await ref.read(databaseProvider).messagesFor(groupId);
    final located = messages
        .where((m) => m.lat != null && m.lng != null)
        .toList();
    if (located.isEmpty) return null;
    final lat =
        located.map((m) => m.lat!).reduce((a, b) => a + b) / located.length;
    final lng =
        located.map((m) => m.lng!).reduce((a, b) => a + b) / located.length;
    return (lat, lng);
  }

  Future<void> _editDescription(String groupId, String? current) async {
    final controller = TextEditingController(text: current);
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Group description'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'What are you mapping, and how?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null) return;
    await ref
        .read(groupServiceProvider)
        .setDescription(groupId, saved.isEmpty ? null : saved);
    final group = await ref.read(databaseProvider).groupById(groupId);
    if (group != null && group.isPublic) {
      final center = await _groupCenter(groupId, group.aoiGeoJson);
      if (center != null) await _publishToDirectory(group, center);
    }
    _reload();
  }

  Future<void> _archive(String groupId) async {
    await ref.read(groupServiceProvider).archiveGroup(groupId);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _leave(String groupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text(
          'It is removed from this device. Other members keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await ref.read(groupServiceProvider).leaveGroup(groupId);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _delete(String groupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this group?'),
        content: const Text(
          'The group and its points are removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await ref.read(groupServiceProvider).deleteGroup(groupId);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Group info')),
      body: FutureBuilder<Group?>(
        future: _groupFuture,
        builder: (context, snapshot) {
          final group = snapshot.data;
          if (group == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final members =
              ref.watch(groupMembersProvider(group.id)).asData?.value ??
              const <GroupMemberView>[];
          final selfId = ref.watch(currentUserIdProvider);
          final iAmAdmin = members.any(
            (m) => m.profileId == selfId && m.isAdmin,
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Identity(
                name: group.name,
                description: group.description,
                photo: group.photo,
                onEditPhoto: _editPhoto,
              ),
              if (!iAmAdmin)
                _AdminInviteWatcher(
                  groupId: group.id,
                  selfId: selfId,
                  onAccept: () => unawaited(_acceptAdmin(group.id)),
                ),
              const SizedBox(height: AppSpacing.lg),
              _InviteLink(
                link: ref.read(groupServiceProvider).inviteLinkFor(group),
              ),
              const SizedBox(height: AppSpacing.lg),
              _MembersCard(
                groupId: group.id,
                inviteLink: ref.read(groupServiceProvider).inviteLinkFor(group),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ManageCard(
                caching: _caching,
                canExport: iAmAdmin || group.allowMemberExport,
                onEditHotKeys: () => _editHotKeys(context, ref, group.id),
                onMakeOffline: () => _makeOffline(group),
                onExport: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ExportSheet(group: group),
                ),
              ),
              if (iAmAdmin && group.isPublic && group.joinApproval) ...[
                const SizedBox(height: AppSpacing.lg),
                _JoinRequestsCard(groupId: group.id),
              ],
              if (iAmAdmin) ...[
                const SizedBox(height: AppSpacing.lg),
                _ModerationCard(
                  isPublic: group.isPublic,
                  hasArea: group.aoiGeoJson != null,
                  joinApproval: group.joinApproval,
                  allowMemberExport: group.allowMemberExport,
                  allowMemberPlace: group.allowMemberPlace,
                  allowOutsideArea: group.allowOutsideArea,
                  gpsLimitM: group.gpsLimitM,
                  onToggleApproval: (value) =>
                      unawaited(_setJoinApproval(group.id, value)),
                  onToggleMemberExport: (value) =>
                      unawaited(_setAllowMemberExport(group.id, value)),
                  onToggleMemberPlace: (value) =>
                      unawaited(_setAllowMemberPlace(group.id, value)),
                  onToggleOutsideArea: (value) =>
                      unawaited(_setAllowOutsideArea(group.id, value)),
                  onEditGpsLimit: () =>
                      unawaited(_editGpsLimit(group.id, group.gpsLimitM)),
                ),
                const SizedBox(height: AppSpacing.lg),
                _AdminCard(
                  isPublic: group.isPublic,
                  onTogglePublic: (value) => _setPublic(group.id, value),
                  onEditDescription: () =>
                      _editDescription(group.id, group.description),
                  onArchive: () => _archive(group.id),
                  onDelete: () => _delete(group.id),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: AppColors.mist),
                  ),
                  child: Material(
                    color: AppColors.white,
                    child: ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Leave group',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () => _leave(group.id),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

Future<void> _editHotKeys(
  BuildContext context,
  WidgetRef ref,
  String groupId,
) async {
  final rows = await ref.read(databaseProvider).hotKeysFor(groupId);
  final initial = [
    for (final row in rows)
      EditableHotKey(
        id: row.id,
        label: row.label,
        colorValue: row.colorValue,
        iconName: row.iconName,
      ),
  ];
  if (!context.mounted) return;
  final result = await Navigator.of(context).push<List<EditableHotKey>>(
    MaterialPageRoute<List<EditableHotKey>>(
      builder: (_) => HotKeyEditorScreen(initial: initial),
    ),
  );
  if (result == null) return;
  await ref.read(groupServiceProvider).updateHotKeys(groupId, result);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quick tags updated')),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.photo,
    required this.onEditPhoto,
    this.description,
  });

  final String name;
  final String? description;
  final Uint8List? photo;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onEditPhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              GroupAvatar(photo: photo, size: 72, radius: 22),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera,
                  size: 14,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(name, style: Theme.of(context).textTheme.titleLarge),
        Text(
          'Mapping group',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            description!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
          ),
        ],
      ],
    );
  }
}

/// Admin-only group controls that shape what members may do: join approval,
/// export, map placement, task-area enforcement, and the accuracy cap.
class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.isPublic,
    required this.hasArea,
    required this.joinApproval,
    required this.allowMemberExport,
    required this.allowMemberPlace,
    required this.allowOutsideArea,
    required this.gpsLimitM,
    required this.onToggleApproval,
    required this.onToggleMemberExport,
    required this.onToggleMemberPlace,
    required this.onToggleOutsideArea,
    required this.onEditGpsLimit,
  });

  final bool isPublic;
  final bool hasArea;
  final bool joinApproval;
  final bool allowMemberExport;
  final bool allowMemberPlace;
  final bool allowOutsideArea;
  final int? gpsLimitM;
  final ValueChanged<bool> onToggleApproval;
  final ValueChanged<bool> onToggleMemberExport;
  final ValueChanged<bool> onToggleMemberPlace;
  final ValueChanged<bool> onToggleOutsideArea;
  final VoidCallback onEditGpsLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.mist),
      ),
      child: Material(
        color: AppColors.white,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MODERATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            if (isPublic) ...[
              SwitchListTile(
                secondary: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.ink,
                ),
                title: const Text('Require approval to join'),
                subtitle: const Text(
                  'People request access; an admin approves',
                ),
                value: joinApproval,
                onChanged: onToggleApproval,
              ),
              const Divider(height: 1),
            ],
            SwitchListTile(
              secondary: const Icon(
                Icons.download_outlined,
                color: AppColors.ink,
              ),
              title: const Text('Allow everyone to export'),
              subtitle: const Text('Members can download the data, not just '
                  'admins'),
              value: allowMemberExport,
              onChanged: onToggleMemberExport,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.ink,
              ),
              title: const Text('Allow members to place points'),
              subtitle: const Text('Off means members can only send their '
                  'live GPS point'),
              value: allowMemberPlace,
              onChanged: onToggleMemberPlace,
            ),
            if (hasArea) ...[
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(
                  Icons.fmd_bad_outlined,
                  color: AppColors.ink,
                ),
                title: const Text('Allow points outside the area'),
                subtitle: const Text('Off blocks sending beyond the task '
                    'area'),
                value: allowOutsideArea,
                onChanged: onToggleOutsideArea,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.gps_fixed,
                color: AppColors.ink,
              ),
              title: const Text('GPS accuracy limit'),
              subtitle: Text(
                gpsLimitM == null
                    ? 'Off. Points send at any accuracy'
                    : 'Refuse points weaker than ±$gpsLimitM m',
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textFaint,
              ),
              onTap: onEditGpsLimit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.isPublic,
    required this.onTogglePublic,
    required this.onEditDescription,
    required this.onArchive,
    required this.onDelete,
  });

  final bool isPublic;
  final ValueChanged<bool> onTogglePublic;
  final VoidCallback onEditDescription;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.mist),
      ),
      child: Material(
        color: AppColors.white,
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.public, color: AppColors.ink),
              title: const Text('Public group'),
              subtitle: const Text('Discoverable by people nearby'),
              value: isPublic,
              onChanged: onTogglePublic,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notes, color: AppColors.ink),
              title: const Text('Edit description'),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textFaint,
              ),
              onTap: onEditDescription,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: AppColors.ink),
              title: const Text('Archive group'),
              onTap: onArchive,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text(
                'Delete group',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteLink extends StatelessWidget {
  const _InviteLink({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.mist),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 18, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVITE LINK',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2, size: 18),
            onPressed: () => unawaited(_showQr(context, link)),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: link)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite link copied')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 18),
            onPressed: () => unawaited(
              SharePlus.instance.share(
                ShareParams(text: 'Join my FieldChat mapping group: $link'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQr(BuildContext context, String link) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan to join',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              QrImageView(
                data: link,
                size: 220,
                backgroundColor: AppColors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersCard extends ConsumerWidget {
  const _MembersCard({required this.groupId, required this.inviteLink});

  final String groupId;
  final String inviteLink;

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    GroupMemberView member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          'They stay off this group’s roster on this device. '
          'Sharing the invite link lets them rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref
          .read(groupServiceProvider)
          .removeMember(groupId, member.profileId);
    }
  }

  /// Invites a member to become an admin. They gain admin rights only after
  /// they accept on their own device.
  Future<void> _promote(
    BuildContext context,
    WidgetRef ref,
    GroupMemberView member,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final identity = await ref.read(deviceIdentityProvider.future);
    final invited = await ref
        .read(groupServiceProvider)
        .inviteAdmin(groupId, member.profileId, identity);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          invited
              ? 'Invited ${member.name} to be an admin'
              : '${member.name} has not shared an identity yet',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMembers =
        ref.watch(groupMembersProvider(groupId)).asData?.value ??
        const <GroupMemberView>[];
    final selfId = ref.watch(currentUserIdProvider);
    final iAmAdmin = allMembers.any((m) => m.profileId == selfId && m.isAdmin);
    // Admins manage everyone; a regular member only sees the admins and self,
    // never the other members.
    final members = iAmAdmin
        ? allMembers
        : allMembers.where((m) => m.isAdmin || m.profileId == selfId).toList();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.mist),
      ),
      child: Material(
        color: AppColors.white,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.group_outlined, color: AppColors.ink),
              title: Text('Members · ${members.length}'),
              trailing: TextButton.icon(
                onPressed: () => unawaited(
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Join my FieldChat mapping group: $inviteLink',
                    ),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add'),
              ),
            ),
            for (final member in members) ...[
              const Divider(height: 1),
              _MemberRow(
                member: member,
                isSelf: member.profileId == selfId,
                canRemove: iAmAdmin && member.profileId != selfId,
                onMakeAdmin: iAmAdmin && !member.isAdmin
                    ? () => unawaited(_promote(context, ref, member))
                    : null,
                onRemove: () => unawaited(_confirmRemove(context, ref, member)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Admin-only list of people asking to join an approval-gated group. Approving
/// seals the group key to the requester's key so only they can open it.
class _JoinRequestsCard extends ConsumerStatefulWidget {
  const _JoinRequestsCard({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_JoinRequestsCard> createState() => _JoinRequestsCardState();
}

class _JoinRequestsCardState extends ConsumerState<_JoinRequestsCard> {
  List<JoinRequest> _requests = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final requests = await ref
        .read(publicDirectoryProvider)
        .pendingRequests(widget.groupId);
    if (mounted) setState(() => _requests = requests);
  }

  Future<void> _approve(JoinRequest request) async {
    final group = await ref.read(databaseProvider).groupById(widget.groupId);
    if (group == null) return;
    final sealed = await IdentityKeys.seal(
      base64Decode(group.encKey),
      recipientAgreementPublic: base64Decode(request.agreementKey),
    );
    await ref
        .read(publicDirectoryProvider)
        .approveRequest(request.id, jsonEncode(sealed));
    await _refresh();
  }

  Future<void> _decline(JoinRequest request) async {
    await ref.read(publicDirectoryProvider).declineRequest(request.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_requests.isEmpty) return const SizedBox.shrink();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.mist),
      ),
      child: Material(
        color: AppColors.white,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.how_to_reg_outlined,
                color: AppColors.ink,
              ),
              title: Text('Join requests · ${_requests.length}'),
            ),
            for (final request in _requests) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(request.requesterName ?? 'Someone'),
                subtitle: const Text('wants to join'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => unawaited(_decline(request)),
                      child: const Text('Decline'),
                    ),
                    FilledButton(
                      onPressed: () => unawaited(_approve(request)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                      ),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Watches the handshake events and shows the accept card while this device has
/// an admin invite it has neither accepted nor declined.
class _AdminInviteWatcher extends ConsumerStatefulWidget {
  const _AdminInviteWatcher({
    required this.groupId,
    required this.selfId,
    required this.onAccept,
  });

  final String groupId;
  final String selfId;
  final VoidCallback onAccept;

  @override
  ConsumerState<_AdminInviteWatcher> createState() =>
      _AdminInviteWatcherState();
}

class _AdminInviteWatcherState extends ConsumerState<_AdminInviteWatcher> {
  String get _declinedKey => 'admin.declined.${widget.groupId}';

  Set<String> _declined() {
    final stored = ref
        .read(sharedPreferencesProvider)
        .getStringList(_declinedKey);
    return stored?.toSet() ?? <String>{};
  }

  /// Declining an admin invite is a local choice: the invite stays in the log
  /// but this device never signs an acceptance, so it never becomes admin. The
  /// specific invite signature is remembered so a fresh re-invite still shows.
  Future<void> _decline(String signature) async {
    final declined = _declined()..add(signature);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_declinedKey, declined.toList());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminEventRow>>(
      stream: ref.watch(databaseProvider).watchAdminEventsFor(widget.groupId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <AdminEventRow>[];
        final invite = events
            .where((e) => e.kind == 'invite' && e.subjectId == widget.selfId)
            .fold<AdminEventRow?>(null, (a, b) => b);
        final accepted = events.any(
          (e) => e.kind == 'accept' && e.actorId == widget.selfId,
        );
        if (invite == null || accepted) return const SizedBox.shrink();
        if (_declined().contains(invite.signature)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: _AdminInviteCard(
            onAccept: widget.onAccept,
            onDecline: () => unawaited(_decline(invite.signature)),
          ),
        );
      },
    );
  }
}

/// Shown when this device has been invited to become an admin. Accepting signs
/// the acceptance so every member can verify the promotion; declining dismisses
/// the invite on this device.
class _AdminInviteCard extends StatelessWidget {
  const _AdminInviteCard({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.ink),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'You have been invited to be an admin.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDecline,
                child: const Text('Decline'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.canRemove,
    required this.onRemove,
    this.onMakeAdmin,
  });

  final GroupMemberView member;
  final bool isSelf;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback? onMakeAdmin;

  @override
  Widget build(BuildContext context) {
    final initial = member.name.characters.first.toUpperCase();
    final hasMenu = canRemove || onMakeAdmin != null;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.mist,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      title: Text(isSelf ? '${member.name} (you)' : member.name),
      subtitle: Text(member.isAdmin ? 'Admin' : 'Member'),
      trailing: hasMenu
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
              onSelected: (value) {
                if (value == 'admin') onMakeAdmin?.call();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (context) => [
                if (onMakeAdmin != null)
                  const PopupMenuItem(
                    value: 'admin',
                    child: Text('Make admin'),
                  ),
                if (canRemove)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.caching,
    required this.canExport,
    required this.onEditHotKeys,
    required this.onMakeOffline,
    required this.onExport,
  });

  final bool caching;
  final bool canExport;
  final VoidCallback onEditHotKeys;
  final VoidCallback onMakeOffline;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.mist),
      ),
      child: Material(
        color: AppColors.white,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.label_outline, color: AppColors.ink),
              title: const Text('Quick tags'),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textFaint,
              ),
              onTap: onEditHotKeys,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.offline_pin_outlined,
                color: AppColors.ink,
              ),
              title: const Text('Make available offline'),
              subtitle: const Text('Save this area’s map tiles'),
              trailing: caching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, color: AppColors.textFaint),
              onTap: caching ? null : onMakeOffline,
            ),
            if (canExport) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.download_outlined,
                  color: AppColors.ink,
                ),
                title: const Text('Export data'),
                subtitle: const Text('Admins only'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textFaint,
                ),
                onTap: onExport,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
