import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/core/image_thumbnail.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/design/app_colors.dart';
import 'package:hulaki/design/app_spacing.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/discovery/listing_publisher.dart';
import 'package:hulaki/features/discovery/public_directory.dart';
import 'package:hulaki/features/export/geojson.dart';
import 'package:hulaki/features/export/presentation/share_web_sheet.dart';
import 'package:hulaki/features/groups/group_member_view.dart';
import 'package:hulaki/features/groups/group_service.dart';
import 'package:hulaki/features/groups/presentation/area_draw_screen.dart';
import 'package:hulaki/features/groups/presentation/export_sheet.dart';
import 'package:hulaki/features/groups/presentation/group_avatar.dart';
import 'package:hulaki/features/groups/presentation/hot_key_editor_screen.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';
import 'package:hulaki/features/map/offline_areas.dart';
import 'package:hulaki/features/map/offline_downloads.dart';
import 'package:hulaki/features/zones/presentation/zone_coverage_screen.dart';
import 'package:hulaki/features/zones/presentation/zone_manage_screen.dart';
import 'package:hulaki/l10n/app_localizations.dart';
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(refreshPublicListing(ref, widget.groupId));
  }

  Future<Group?> _loadGroup() =>
      ref.read(databaseProvider).groupById(widget.groupId);

  /// Runs a group mutation while showing the top progress bar, so a save that
  /// waits on the network reads as working rather than stuck.
  Future<void> _guard(Future<void> Function() op) async {
    if (mounted) setState(() => _saving = true);
    try {
      await op();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    await _guard(() async {
      final bytes = squareJpegThumbnail(await file.readAsBytes());
      await ref
          .read(groupServiceProvider)
          .updateGroupPhoto(widget.groupId, bytes);
      _reload();
    });
  }

  Future<void> _makeOffline(Group group, AppLocalizations l10n) async {
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
            SnackBar(
              content: Text(l10n.groupNeedAreaOrPoints),
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
          SnackBar(content: Text(l10n.groupOfflineAreaSaved)),
        );
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupOfflineDownloadFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _caching = false);
    }
  }

  /// Toggles join approval and, for a public group, republishes the directory
  /// listing so it withholds or restores the key to match.
  Future<void> _setJoinApproval(String groupId, bool value) => _guard(() async {
    await ref.read(groupServiceProvider).setJoinApproval(groupId, value: value);
    await refreshPublicListing(ref, groupId);
    _reload();
  });

  Future<void> _setAllowMemberExport(String groupId, bool value) =>
      _guard(() async {
        await ref
            .read(groupServiceProvider)
            .setAllowMemberExport(groupId, value: value);
        _reload();
      });

  Future<void> _setAllowMemberPlace(String groupId, bool value) =>
      _guard(() async {
        await ref
            .read(groupServiceProvider)
            .setAllowMemberPlace(groupId, value: value);
        _reload();
      });

  Future<void> _setAllowOutsideArea(String groupId, bool value) =>
      _guard(() async {
        await ref
            .read(groupServiceProvider)
            .setAllowOutsideArea(groupId, value: value);
        _reload();
      });

  Future<void> _setAllowMemberTags(String groupId, bool value) =>
      _guard(() async {
        await ref
            .read(groupServiceProvider)
            .setAllowMemberTags(groupId, value: value);
        _reload();
      });

  Future<void> _setAllowChatMode(String groupId, bool value) =>
      _guard(() async {
        await ref
            .read(groupServiceProvider)
            .setAllowChatMode(groupId, value: value);
        _reload();
      });

  Future<void> _setRequireZone(String groupId, bool value) => _guard(() async {
    await ref.read(groupServiceProvider).setRequireZone(groupId, value: value);
    _reload();
  });

  /// Picks the accuracy cap for sent points. Off clears it; the presets bound
  /// the metres a fix may carry before a send is refused.
  Future<void> _editGpsLimit(
    String groupId,
    int? current,
    AppLocalizations l10n,
  ) async {
    const presets = <int?>[null, 5, 10, 15, 20];
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.groupRequireGoodGps),
        children: [
          for (final preset in presets)
            ListTile(
              title: Text(
                preset == null
                    ? l10n.groupGpsLimitOff
                    : l10n.groupGpsLimitWithin(preset),
              ),
              trailing: (current ?? 0) == (preset ?? 0)
                  ? const Icon(Icons.check, color: AppColors.ink)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(preset ?? 0),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await _guard(() async {
      await ref
          .read(groupServiceProvider)
          .setGpsLimit(groupId, chosen == 0 ? null : chosen);
      _reload();
    });
  }

  Future<void> _acceptAdmin(String groupId, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final identity = await ref.read(deviceIdentityProvider.future);
    await ref.read(groupServiceProvider).acceptAdmin(groupId, identity);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.groupNowAdmin)),
    );
  }

  Future<void> _setReach(
    String groupId,
    String reach,
    AppLocalizations l10n,
  ) => _guard(() async {
    final service = ref.read(groupServiceProvider);
    final directory = ref.read(publicDirectoryProvider);
    final db = ref.read(databaseProvider);
    final group = await db.groupById(groupId);
    if (group == null) return;
    if (reach == 'private') {
      await service.setReach(groupId, isPublic: false);
      await directory.remove(groupId);
      _reload();
      return;
    }
    // Nearby needs a locatable centre; Everyone lists with no location.
    (double, double)? center;
    if (reach == 'local') {
      center = await _groupCenter(groupId, group.aoiGeoJson);
      if (center == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.groupNeedAreaBeforePublic)),
          );
        }
        return;
      }
    }
    await service.setReach(groupId, isPublic: true, scope: reach);
    final updated = await db.groupById(groupId);
    if (updated != null) await publishGroupListing(ref, updated, center);
    _reload();
  });

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

  /// Persists an inline edit of the group's name and description, then keeps
  /// the public listing current. Only changed fields are written.
  Future<void> _saveIdentity(
    Group group,
    String name,
    String? description,
  ) {
    if (name == group.name && description == group.description) {
      return Future<void>.value();
    }
    return _guard(() async {
      final service = ref.read(groupServiceProvider);
      if (name.isNotEmpty && name != group.name) {
        await service.renameGroup(group.id, name);
      }
      if (description != group.description) {
        await service.setDescription(group.id, description);
      }
      await refreshPublicListing(ref, group.id);
      _reload();
    });
  }

  /// Draws or replaces the group's mapping area after creation, then keeps the
  /// public listing current.
  Future<void> _editMappingArea(String groupId) async {
    final area =
        (await ref.read(databaseProvider).groupById(groupId))?.aoiGeoJson;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final geoJson = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => AreaDrawScreen(initialArea: area),
      ),
    );
    if (geoJson == null) return;
    await _guard(() async {
      await ref.read(groupServiceProvider).setMappingArea(groupId, geoJson);
      await refreshPublicListing(ref, groupId);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupBoundarySaved)),
        );
      }
    });
  }

  Future<void> _archive(String groupId) async {
    await ref.read(groupServiceProvider).archiveGroup(groupId);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _leave(String groupId, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.groupLeaveConfirmTitle),
        content: Text(l10n.groupLeaveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.groupCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.groupLeaveAction),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await ref.read(groupServiceProvider).leaveGroup(groupId);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _delete(
    String groupId,
    String groupName,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final matches = controller.text.trim() == groupName.trim();
          return AlertDialog(
            title: Text(l10n.groupDeleteConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.groupDeleteConfirmBody),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.groupDeleteTypeName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: groupName,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.groupCancel),
              ),
              FilledButton(
                onPressed: matches
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(l10n.groupDeleteAction),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (!(confirmed ?? false)) return;
    await ref.read(publicDirectoryProvider).remove(groupId);
    await ref.read(groupServiceProvider).deleteGroupForEveryone(groupId);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(l10n.groupInfoTitle),
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
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
              _EditableIdentity(
                name: group.name,
                description: group.description,
                photo: group.photo,
                canEdit: iAmAdmin,
                onEditPhoto: _editPhoto,
                onSave: (name, description) =>
                    unawaited(_saveIdentity(group, name, description)),
              ),
              if (!iAmAdmin)
                _AdminInviteWatcher(
                  groupId: group.id,
                  selfId: selfId,
                  onAccept: () => unawaited(_acceptAdmin(group.id, l10n)),
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
              if (iAmAdmin) ...[
                const SizedBox(height: AppSpacing.lg),
                _AreaCard(
                  groupId: group.id,
                  hasZones: group.zonesGeoJson != null,
                  onEditArea: () => unawaited(_editMappingArea(group.id)),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _ManageCard(
                caching: _caching,
                canExport: iAmAdmin || group.allowMemberExport,
                exportForEveryone: group.allowMemberExport,
                onEditHotKeys: () => _editHotKeys(
                  context,
                  ref,
                  group.id,
                  l10n,
                  editable: iAmAdmin || group.allowMemberTags,
                ),
                onMakeOffline: () => _makeOffline(group, l10n),
                onExport: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ExportSheet(group: group),
                ),
                onShareWeb: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ShareWebSheet(group: group),
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
                  hasZones: group.zonesGeoJson != null,
                  joinApproval: group.joinApproval,
                  allowMemberExport: group.allowMemberExport,
                  allowMemberPlace: group.allowMemberPlace,
                  allowOutsideArea: group.allowOutsideArea,
                  allowMemberTags: group.allowMemberTags,
                  allowChatMode: group.allowChatMode,
                  requireZone: group.requireZone,
                  gpsLimitM: group.gpsLimitM,
                  onToggleApproval: (value) =>
                      unawaited(_setJoinApproval(group.id, value)),
                  onToggleMemberExport: (value) =>
                      unawaited(_setAllowMemberExport(group.id, value)),
                  onToggleMemberPlace: (value) =>
                      unawaited(_setAllowMemberPlace(group.id, value)),
                  onToggleOutsideArea: (value) =>
                      unawaited(_setAllowOutsideArea(group.id, value)),
                  onToggleMemberTags: (value) =>
                      unawaited(_setAllowMemberTags(group.id, value)),
                  onToggleChatMode: (value) =>
                      unawaited(_setAllowChatMode(group.id, value)),
                  onToggleRequireZone: (value) =>
                      unawaited(_setRequireZone(group.id, value)),
                  onEditGpsLimit: () => unawaited(
                    _editGpsLimit(group.id, group.gpsLimitM, l10n),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _AdminCard(
                  reach: group.isPublic ? group.scope : 'private',
                  onSetReach: (reach) => _setReach(group.id, reach, l10n),
                  onArchive: () => _archive(group.id),
                  onDelete: () => _delete(group.id, group.name, l10n),
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
                      title: Text(
                        l10n.groupLeaveGroup,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      onTap: () => _leave(group.id, l10n),
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
  AppLocalizations l10n, {
  required bool editable,
}) async {
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
      builder: (_) => HotKeyEditorScreen(initial: initial, editable: editable),
    ),
  );
  if (result == null) return;
  await ref.read(groupServiceProvider).updateHotKeys(groupId, result);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.groupQuickTagsUpdated)),
    );
  }
}

/// The group's photo, name and description. An admin edits the name and
/// description in place: tapping the pencil reveals the fields, and tapping
/// anywhere outside them saves and closes, so no separate button is needed.
class _EditableIdentity extends StatefulWidget {
  const _EditableIdentity({
    required this.name,
    required this.photo,
    required this.canEdit,
    required this.onEditPhoto,
    required this.onSave,
    this.description,
  });

  final String name;
  final String? description;
  final Uint8List? photo;
  final bool canEdit;
  final VoidCallback onEditPhoto;
  final void Function(String name, String? description) onSave;

  @override
  State<_EditableIdentity> createState() => _EditableIdentityState();
}

class _EditableIdentityState extends State<_EditableIdentity> {
  bool _editing = false;
  late final TextEditingController _nameController = TextEditingController(
    text: widget.name,
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.description ?? '');

  @override
  void didUpdateWidget(_EditableIdentity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      _nameController.text = widget.name;
      _descriptionController.text = widget.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _commit() {
    if (!_editing) return;
    setState(() => _editing = false);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    widget.onSave(name, description.isEmpty ? null : description);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = widget.description;
    return Column(
      children: [
        GestureDetector(
          onTap: widget.onEditPhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              GroupAvatar(photo: widget.photo, size: 72, radius: 22),
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
        if (_editing)
          TapRegion(
            onTapOutside: (_) => _commit(),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.groupNameLabel,
                    border: InputBorder.none,
                  ),
                ),
                TextField(
                  controller: _descriptionController,
                  textAlign: TextAlign.center,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.groupDescriptionHint,
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (widget.canEdit)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _editing = true),
                ),
            ],
          ),
          Text(
            l10n.groupMappingGroupSubtitle,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
            ),
          ],
        ],
      ],
    );
  }
}

/// Admin-only group controls that shape what members may do: join approval,
/// export, map placement, mapping-area enforcement, tag editing, and the
/// accuracy cap.
class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.isPublic,
    required this.hasArea,
    required this.hasZones,
    required this.joinApproval,
    required this.allowMemberExport,
    required this.allowMemberPlace,
    required this.allowOutsideArea,
    required this.allowMemberTags,
    required this.allowChatMode,
    required this.requireZone,
    required this.gpsLimitM,
    required this.onToggleApproval,
    required this.onToggleMemberExport,
    required this.onToggleMemberPlace,
    required this.onToggleOutsideArea,
    required this.onToggleMemberTags,
    required this.onToggleChatMode,
    required this.onToggleRequireZone,
    required this.onEditGpsLimit,
  });

  final bool isPublic;
  final bool hasArea;
  final bool hasZones;
  final bool joinApproval;
  final bool allowMemberExport;
  final bool allowMemberPlace;
  final bool allowOutsideArea;
  final bool allowMemberTags;
  final bool allowChatMode;
  final bool requireZone;
  final int? gpsLimitM;
  final ValueChanged<bool> onToggleApproval;
  final ValueChanged<bool> onToggleMemberExport;
  final ValueChanged<bool> onToggleMemberPlace;
  final ValueChanged<bool> onToggleOutsideArea;
  final ValueChanged<bool> onToggleMemberTags;
  final ValueChanged<bool> onToggleChatMode;
  final ValueChanged<bool> onToggleRequireZone;
  final VoidCallback onEditGpsLimit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gpsLimit = gpsLimitM;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.groupModerationHeading,
                  style: const TextStyle(
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
                title: Text(l10n.groupRequireApproval),
                subtitle: Text(l10n.groupRequireApprovalDetail),
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
              title: Text(l10n.groupAllowMemberExport),
              subtitle: Text(l10n.groupAllowMemberExportDetail),
              value: allowMemberExport,
              onChanged: onToggleMemberExport,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.ink,
              ),
              title: Text(l10n.groupAllowMemberPlace),
              subtitle: Text(l10n.groupAllowMemberPlaceDetail),
              value: allowMemberPlace,
              onChanged: onToggleMemberPlace,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(
                Icons.label_outline,
                color: AppColors.ink,
              ),
              title: Text(l10n.groupAllowMemberTags),
              subtitle: Text(l10n.groupAllowMemberTagsDetail),
              value: allowMemberTags,
              onChanged: onToggleMemberTags,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.ink,
              ),
              title: Text(l10n.groupAllowChatMode),
              subtitle: Text(l10n.groupAllowChatModeDetail),
              value: allowChatMode,
              onChanged: onToggleChatMode,
            ),
            if (hasArea) ...[
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(
                  Icons.fmd_bad_outlined,
                  color: AppColors.ink,
                ),
                title: Text(l10n.groupAllowOutsideArea),
                subtitle: Text(l10n.groupAllowOutsideAreaDetail),
                value: allowOutsideArea,
                onChanged: onToggleOutsideArea,
              ),
            ],
            if (hasZones) ...[
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(
                  Icons.grid_view_outlined,
                  color: AppColors.ink,
                ),
                title: Text(l10n.groupRequireZone),
                subtitle: Text(l10n.groupRequireZoneDetail),
                value: requireZone,
                onChanged: onToggleRequireZone,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.gps_fixed,
                color: AppColors.ink,
              ),
              title: Text(l10n.groupRequireGoodGps),
              subtitle: Text(
                gpsLimit == null
                    ? l10n.groupGpsLimitOffDetail
                    : l10n.groupGpsLimitDetail(gpsLimit),
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
    required this.reach,
    required this.onSetReach,
    required this.onArchive,
    required this.onDelete,
  });

  /// 'private', 'local' or 'global'.
  final String reach;
  final ValueChanged<String> onSetReach;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public, color: AppColors.ink),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        l10n.groupReach,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.groupReachDetail,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 'private',
                        label: Text(l10n.groupReachPrivate),
                      ),
                      ButtonSegment(
                        value: 'local',
                        label: Text(l10n.groupReachNearby),
                      ),
                      ButtonSegment(
                        value: 'global',
                        label: Text(l10n.groupReachEveryone),
                      ),
                    ],
                    selected: {reach},
                    onSelectionChanged: (selection) =>
                        onSetReach(selection.first),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: AppColors.ink),
              title: Text(l10n.groupArchiveGroup),
              onTap: onArchive,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: Text(
                l10n.groupDeleteGroup,
                style: const TextStyle(color: AppColors.danger),
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
    final l10n = AppLocalizations.of(context);
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
                  l10n.groupInviteLinkHeading,
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
            onPressed: () => unawaited(_showQr(context, link, l10n)),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: link)));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.groupInviteLinkCopied)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 18),
            onPressed: () => unawaited(
              SharePlus.instance.share(
                ShareParams(text: l10n.groupShareInvite(link)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQr(
    BuildContext context,
    String link,
    AppLocalizations l10n,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.groupScanToJoin,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
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
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.groupRemoveMemberTitle(member.name)),
        content: Text(l10n.groupRemoveMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.groupCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.groupRemoveAction),
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
    AppLocalizations l10n,
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
              ? l10n.groupAdminInviteSent(member.name)
              : l10n.groupMemberHasNoIdentity(member.name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
              // The count is always the true group total; a non-admin still
              // only sees the admins plus themselves listed below.
              title: Text(l10n.groupMemberCount(allMembers.length)),
              trailing: TextButton.icon(
                onPressed: () => unawaited(
                  SharePlus.instance.share(
                    ShareParams(text: l10n.groupShareInvite(inviteLink)),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: Text(l10n.groupAddMember),
              ),
            ),
            for (final member in members) ...[
              const Divider(height: 1),
              _MemberRow(
                member: member,
                isSelf: member.profileId == selfId,
                canRemove: iAmAdmin && member.profileId != selfId,
                onMakeAdmin: iAmAdmin && !member.isAdmin
                    ? () => unawaited(_promote(context, ref, member, l10n))
                    : null,
                onRemove: () =>
                    unawaited(_confirmRemove(context, ref, member, l10n)),
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
    final l10n = AppLocalizations.of(context);
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
              title: Text(l10n.groupJoinRequestCount(_requests.length)),
            ),
            for (final request in _requests) ...[
              const Divider(height: 1),
              ListTile(
                title: Text(request.requesterName ?? l10n.groupSomeone),
                subtitle: Text(l10n.groupWantsToJoin),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => unawaited(_decline(request)),
                      child: Text(l10n.groupDecline),
                    ),
                    FilledButton(
                      onPressed: () => unawaited(_approve(request)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                      ),
                      child: Text(l10n.groupApprove),
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
    final l10n = AppLocalizations.of(context);
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
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.ink),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l10n.groupAdminInvitePrompt,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
                child: Text(l10n.groupDecline),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: onAccept,
                style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                child: Text(l10n.groupAccept),
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
    final l10n = AppLocalizations.of(context);
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
      title: Text(
        isSelf ? l10n.groupMemberNameSelf(member.name) : member.name,
      ),
      subtitle: Text(
        member.isAdmin ? l10n.groupRoleAdmin : l10n.groupRoleMember,
      ),
      trailing: hasMenu
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
              onSelected: (value) {
                if (value == 'admin') onMakeAdmin?.call();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (context) => [
                if (onMakeAdmin != null)
                  PopupMenuItem(
                    value: 'admin',
                    child: Text(l10n.groupMakeAdmin),
                  ),
                if (canRemove)
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      l10n.groupRemoveAction,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.groupId,
    required this.hasZones,
    required this.onEditArea,
  });

  final String groupId;
  final bool hasZones;
  final VoidCallback onEditArea;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.groupAreaHeading,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined, color: AppColors.ink),
              title: Text(l10n.groupAreaBoundary),
              subtitle: Text(l10n.groupAreaBoundaryDetail),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textFaint,
              ),
              onTap: onEditArea,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.grid_view_outlined,
                color: AppColors.ink,
              ),
              title: Text(l10n.zoneManageEntry),
              subtitle: Text(l10n.zoneManageEntryDetail),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textFaint,
              ),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ZoneManageScreen(groupId: groupId),
                ),
              ),
            ),
            if (hasZones) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.insights_outlined,
                  color: AppColors.ink,
                ),
                title: Text(l10n.zoneCoverageTitle),
                subtitle: Text(l10n.zoneCoverageEntryDetail),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textFaint,
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ZoneCoverageScreen(groupId: groupId),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.caching,
    required this.canExport,
    required this.exportForEveryone,
    required this.onEditHotKeys,
    required this.onMakeOffline,
    required this.onExport,
    required this.onShareWeb,
  });

  final bool caching;
  final bool canExport;
  final bool exportForEveryone;
  final VoidCallback onEditHotKeys;
  final VoidCallback onMakeOffline;
  final VoidCallback onExport;
  final VoidCallback onShareWeb;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              title: Text(l10n.groupQuickTagsTitle),
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
              title: Text(l10n.groupMakeOffline),
              subtitle: Text(l10n.groupMakeOfflineDetail),
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
                title: Text(l10n.groupExportTitle),
                subtitle: Text(
                  exportForEveryone
                      ? l10n.groupExportEveryoneDetail
                      : l10n.groupExportAdminsOnlyDetail,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textFaint,
                ),
                onTap: onExport,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.public, color: AppColors.ink),
                title: Text(l10n.groupShareWebTitle),
                subtitle: Text(l10n.groupShareWebDetail),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textFaint,
                ),
                onTap: onShareWeb,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
