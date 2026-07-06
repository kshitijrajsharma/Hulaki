import 'dart:typed_data';

import 'package:fieldchat/core/time_format.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
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

class _Photo extends StatelessWidget {
  const _Photo(this.bubble);

  final MessageBubble bubble;

  @override
  Widget build(BuildContext context) {
    final resolver = bubble.mediaResolver;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          SizedBox(
            width: 220,
            height: 130,
            child: resolver == null
                ? const ColoredBox(color: AppColors.mist)
                : FutureBuilder<Uint8List?>(
                    future: resolver(bubble.message.mediaId!),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const ColoredBox(color: AppColors.mist);
                      }
                      return Image.memory(bytes, fit: BoxFit.cover);
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
            'location pending',
            style: TextStyle(fontSize: 11, color: AppColors.amberText),
          )
        else if (message.accuracyM != null)
          Text(
            '±${message.accuracyM!.round()} m',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: message.accuracyM! <= 15
                  ? AppColors.gpsStrong
                  : AppColors.amber,
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
