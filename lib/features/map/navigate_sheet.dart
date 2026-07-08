import 'dart:async';

import 'package:fieldchat/design/app_colors.dart';
import 'package:fieldchat/design/app_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showNavigateSheet({
  required BuildContext context,
  required double lat,
  required double lng,
  String? label,
}) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    final place = Uri.encodeComponent(
      label == null || label.isEmpty ? 'FieldChat point' : label,
    );
    await launchUrl(
      Uri.parse('geo:$lat,$lng?q=$lat,$lng($place)'),
      mode: LaunchMode.externalApplication,
    );
    return;
  }

  final apps = await _installedMapApps(lat, lng);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Navigate with',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final app in apps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(app.icon, color: AppColors.ink),
                title: Text(app.name),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(
                    launchUrl(app.uri, mode: LaunchMode.externalApplication),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class _MapApp {
  const _MapApp({required this.name, required this.icon, required this.uri});

  final String name;
  final IconData icon;
  final Uri uri;
}

Future<List<_MapApp>> _installedMapApps(double lat, double lng) async {
  final apps = <_MapApp>[
    _MapApp(
      name: 'Apple Maps',
      icon: Icons.map_outlined,
      uri: Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d'),
    ),
  ];

  final googleInstalled = await canLaunchUrl(Uri.parse('comgooglemaps://'));
  apps.add(
    _MapApp(
      name: 'Google Maps',
      icon: Icons.navigation_outlined,
      uri: Uri.parse(
        googleInstalled
            ? 'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'
            : 'https://www.google.com/maps/dir/?api=1'
                  '&destination=$lat,$lng&travelmode=driving',
      ),
    ),
  );

  if (await canLaunchUrl(Uri.parse('waze://'))) {
    apps.add(
      _MapApp(
        name: 'Waze',
        icon: Icons.navigation_outlined,
        uri: Uri.parse('waze://?ll=$lat,$lng&navigate=yes'),
      ),
    );
  }
  if (await canLaunchUrl(Uri.parse('osmandmaps://'))) {
    apps.add(
      _MapApp(
        name: 'OsmAnd',
        icon: Icons.navigation_outlined,
        uri: Uri.parse('osmandmaps://navigate?lat=$lat&lon=$lng'),
      ),
    );
  }
  return apps;
}
