import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/primary_button.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/groups/hot_key_icons.dart';
import 'package:flutter/material.dart';

/// Add, rename, recolour and remove a group's hot-keys. Returns the edited
/// list, or null if cancelled.
class HotKeyEditorScreen extends StatefulWidget {
  const HotKeyEditorScreen({
    required this.initial,
    this.editable = true,
    super.key,
  });

  final List<EditableHotKey> initial;

  /// When false the screen only lists the tags: non-admins may view them but
  /// an admin has kept tag editing to admins only.
  final bool editable;

  @override
  State<HotKeyEditorScreen> createState() => _HotKeyEditorScreenState();
}

class _HotKeyEditorScreenState extends State<HotKeyEditorScreen> {
  late final List<EditableHotKey> _hotKeys = [
    for (final h in widget.initial)
      EditableHotKey(
        id: h.id,
        label: h.label,
        colorValue: h.colorValue,
        iconName: h.iconName,
      ),
  ];

  Future<void> _edit({EditableHotKey? existing}) async {
    final result = await showDialog<EditableHotKey>(
      context: context,
      builder: (context) => _HotKeyDialog(existing: existing),
    );
    if (result == null) return;
    setState(() {
      if (existing == null) {
        _hotKeys.add(result);
      } else {
        existing
          ..label = result.label
          ..colorValue = result.colorValue
          ..iconName = result.iconName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick tags')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final hotKey in _hotKeys)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(hotKey.colorValue),
                      child: hotKeyIcon(hotKey.iconName) == null
                          ? null
                          : Icon(
                              hotKeyIcon(hotKey.iconName),
                              size: 16,
                              color: AppColors.white,
                            ),
                    ),
                    title: Text(hotKey.label),
                    trailing: widget.editable
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.danger,
                            ),
                            onPressed: () =>
                                setState(() => _hotKeys.remove(hotKey)),
                          )
                        : null,
                    onTap: widget.editable
                        ? () => _edit(existing: hotKey)
                        : null,
                  ),
                if (widget.editable)
                  TextButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add),
                    label: const Text('Add tag'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: widget.editable
                ? PrimaryButton(
                    label: 'Done',
                    onPressed: _hotKeys.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_hotKeys),
                  )
                : PrimaryButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HotKeyDialog extends StatefulWidget {
  const _HotKeyDialog({this.existing});

  final EditableHotKey? existing;

  @override
  State<_HotKeyDialog> createState() => _HotKeyDialogState();
}

class _HotKeyDialogState extends State<_HotKeyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late int _color =
      widget.existing?.colorValue ?? TagColors.palette.first.toARGB32();
  late String? _icon = widget.existing?.iconName;
  String _iconQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final entry in kHotKeyIcons.entries)
        if (_iconQuery.isEmpty || entry.key.contains(_iconQuery)) entry,
    ];
    return AlertDialog(
      title: Text(widget.existing == null ? 'New tag' : 'Edit tag'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Label, e.g. Pothole',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final color in TagColors.palette)
                    GestureDetector(
                      onTap: () => setState(() => _color = color.toARGB32()),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == color.toARGB32()
                                ? AppColors.ink
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Icon (optional)',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                onChanged: (value) =>
                    setState(() => _iconQuery = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Search icons (tree, water, sign…)',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 150,
                child: GridView.count(
                  crossAxisCount: 6,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    if (_iconQuery.isEmpty)
                      _IconChoice(
                        selected: _icon == null,
                        onTap: () => setState(() => _icon = null),
                        child: const Icon(Icons.block, size: 18),
                      ),
                    for (final entry in matches)
                      _IconChoice(
                        selected: _icon == entry.key,
                        onTap: () => setState(() => _icon = entry.key),
                        child: Icon(entry.value, size: 18),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final label = _controller.text.trim();
            if (label.isEmpty) return;
            Navigator.of(context).pop(
              EditableHotKey(
                id: widget.existing?.id,
                label: label,
                colorValue: _color,
                iconName: _icon,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.mist,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconTheme(
          data: IconThemeData(
            color: selected ? AppColors.white : AppColors.ink,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
