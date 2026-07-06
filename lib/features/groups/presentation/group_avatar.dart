import 'dart:typed_data';

import 'package:fieldchat/design/app_colors.dart';
import 'package:flutter/material.dart';

/// The group's cover photo, or a neutral pin when none is set. Used in the
/// chats list, group info and the map overview so a group looks the same
/// everywhere.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    required this.photo,
    this.size = 46,
    this.radius = 14,
    super.key,
  });

  final Uint8List? photo;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = photo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image == null
          ? Icon(
              Icons.location_on_outlined,
              color: AppColors.ink,
              size: size * 0.5,
            )
          : Image.memory(image, fit: BoxFit.cover, width: size, height: size),
    );
  }
}
