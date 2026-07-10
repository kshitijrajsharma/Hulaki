import 'dart:typed_data';

import 'package:fieldchat/core/time_format.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:fieldchat/design/widgets/gps_strip.dart';
import 'package:flutter/material.dart';

typedef MediaResolver = Future<Uint8List?> Function(String mediaId);

/// One field observation in the thread: an optional photo, a tag chip, the
/// text or caption, and the location accuracy that travels with every point.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
    this.anonymous = false,
    this.tagLabel,
    this.tagColor,
    this.tagIcon,
    this.mediaResolver,
    super.key,
  });

  final Message message;
  final bool isMine;
  final String? senderName;
  final bool anonymous;
  final String? tagLabel;
  final Color? tagColor;
  final IconData? tagIcon;
  final MediaResolver? mediaResolver;

  @override
  Widget build(BuildContext context) {
    final radius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(AppRadii.bubble),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(AppRadii.bubble),
            bottomRight: Radius.circular(AppRadii.bubble),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(AppRadii.bubble),
            bottomLeft: Radius.circular(AppRadii.bubble),
            bottomRight: Radius.circular(AppRadii.bubble),
          );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFE9E6DE) : AppColors.white,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (anonymous)
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 2, 2, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Anonymous',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            else if (!isMine && senderName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            if (message.mediaId != null)
              _Photo(this)
            else if (tagLabel != null)
              _TagChip(
                label: tagLabel!,
                color: tagColor ?? AppColors.ink,
                icon: tagIcon,
              ),
            if (message.body != null && message.body!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
                child: Text(
                  message.body!,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
              child: _MetaRow(message: message, isMine: isMine),
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatefulWidget {
  const _Photo(this.bubble);

  final MessageBubble bubble;

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  // Resolved once and reused, so the thread restreaming on every new message
  // does not re-read and re-decode every visible photo's bytes each rebuild.
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_Photo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bubble.message.mediaId != widget.bubble.message.mediaId) {
      _resolve();
    }
  }

  void _resolve() {
    final resolver = widget.bubble.mediaResolver;
    final mediaId = widget.bubble.message.mediaId;
    _bytes = resolver != null && mediaId != null ? resolver(mediaId) : null;
  }

  @override
  Widget build(BuildContext context) {
    final bubble = widget.bubble;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          SizedBox(
            width: 220,
            height: 130,
            child: _bytes == null
                ? const ColoredBox(color: AppColors.mist)
                : FutureBuilder<Uint8List?>(
                    future: _bytes,
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const ColoredBox(color: AppColors.mist);
                      }
                      // The bubble is 220 wide; decode near that, not the
                      // stored full resolution, to save memory and jank.
                      return Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 440,
                      );
                    },
                  ),
          ),
          if (bubble.tagLabel != null)
            Positioned(
              top: 7,
              left: 7,
              child: _TagChip(
                label: bubble.tagLabel!,
                color: bubble.tagColor ?? AppColors.ink,
                icon: bubble.tagIcon,
                onPhoto: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.color,
    this.icon,
    this.onPhoto = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onPhoto ? AppColors.ink.withValues(alpha: 0.92) : color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: AppColors.white)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (message.locationPending)
          const Text(
            'Finding location…',
            style: TextStyle(fontSize: 11, color: AppColors.amberText),
          )
        else if (message.accuracyM != null)
          Text(
            '±${message.accuracyM!.round()} m',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: gpsTierFor(message.accuracyM).color,
            ),
          )
        else if (message.lat != null)
          const Text(
            'placed on map',
            style: TextStyle(fontSize: 11, color: AppColors.textFaint),
          ),
        const Spacer(),
        TimeLabel(message.createdAt),
        if (isMine) ...[
          const SizedBox(width: 3),
          Icon(
            message.sendState == 'pending' ? Icons.schedule : Icons.done_all,
            size: 12,
            color: AppColors.textFaint,
          ),
        ],
      ],
    );
  }
}

/// A timestamp that reads as a relative label ("3m") and reveals the exact
/// local time on tap. Used wherever a message time is shown.
class TimeLabel extends StatefulWidget {
  const TimeLabel(this.when, {super.key});

  final DateTime when;

  @override
  State<TimeLabel> createState() => _TimeLabelState();
}

class _TimeLabelState extends State<TimeLabel> {
  bool _exact = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _exact = !_exact),
      child: Text(
        _exact ? exactTime(widget.when) : relativeTime(widget.when),
        style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
      ),
    );
  }
}
