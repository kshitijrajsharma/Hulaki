import 'dart:typed_data';

import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/core/image_thumbnail.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/hot_key_chip.dart';
import 'package:fieldchat/design/widgets/primary_button.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/groups/hot_key_icons.dart';
import 'package:fieldchat/features/groups/presentation/area_draw_screen.dart';
import 'package:fieldchat/features/groups/presentation/group_avatar.dart';
import 'package:fieldchat/features/groups/presentation/hot_key_editor_screen.dart';
import 'package:fieldchat/features/messaging/presentation/chat_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Start a group and set the hot-keys everyone will tap while mapping.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _controller = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  bool _busy = false;
  String? _aoiGeoJson;
  Uint8List? _photo;
  final List<EditableHotKey> _hotKeys = [
    EditableHotKey(label: 'Trash', colorValue: 0xFF15181B, iconName: 'delete'),
    EditableHotKey(
      label: 'Crossings',
      colorValue: 0xFFE0922A,
      iconName: 'crossing',
    ),
    EditableHotKey(
      label: 'Streetlight',
      colorValue: 0xFF7B6FC4,
      iconName: 'streetlight',
    ),
    EditableHotKey(label: 'Pole', colorValue: 0xFFC4615E, iconName: 'bolt'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _editHotKeys() async {
    final result = await Navigator.of(context).push<List<EditableHotKey>>(
      MaterialPageRoute<List<EditableHotKey>>(
        builder: (_) => HotKeyEditorScreen(initial: _hotKeys),
      ),
    );
    if (result != null) {
      setState(() {
        _hotKeys
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = squareJpegThumbnail(await file.readAsBytes());
    if (mounted) setState(() => _photo = bytes);
  }

  Future<void> _drawArea() async {
    final aoi = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const AreaDrawScreen()),
    );
    if (aoi != null) setState(() => _aoiGeoJson = aoi);
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      final group = await ref
          .read(groupServiceProvider)
          .createGroup(
            name: name,
            identity: identity,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            hotKeys: [
              for (final h in _hotKeys)
                HotKeySpec(
                  label: h.label,
                  colorValue: h.colorValue,
                  iconName: h.iconName,
                ),
            ],
            aoiGeoJson: _aoiGeoJson,
            photo: _photo,
          );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatThreadScreen(groupId: group.id, groupName: group.name),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New mapping group')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                GroupAvatar(
                                  photo: _photo,
                                  size: 72,
                                  radius: 22,
                                ),
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
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Set a cover photo',
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'Group name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Ward 7 · Litter survey',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.field),
                          borderSide: const BorderSide(color: AppColors.mist),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.field),
                          borderSide: const BorderSide(
                            color: AppColors.ink,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _create(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Description (optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'What are you mapping, and how?',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.field),
                          borderSide: const BorderSide(color: AppColors.mist),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.field),
                          borderSide: const BorderSide(
                            color: AppColors.ink,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'QUICK TAGS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        TextButton(
                          onPressed: _editHotKeys,
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                    const Text(
                      'Quick tags everyone taps while sending. They caption '
                      'the capture and colour its pin on the map.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final hotKey in _hotKeys)
                          HotKeyChip(
                            label: hotKey.label,
                            color: Color(hotKey.colorValue),
                            icon: hotKeyIcon(hotKey.iconName),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton.icon(
                      onPressed: _drawArea,
                      icon: Icon(
                        _aoiGeoJson == null ? Icons.draw_outlined : Icons.check,
                        size: 18,
                      ),
                      label: Text(
                        _aoiGeoJson == null
                            ? 'Set mapping area (optional)'
                            : 'Mapping area set',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.mist),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: PrimaryButton(
                label: _busy ? 'Creating…' : 'Create group',
                onPressed: (_busy || _controller.text.trim().isEmpty)
                    ? null
                    : _create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
