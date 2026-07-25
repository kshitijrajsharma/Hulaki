import 'dart:async';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:geolocator/geolocator.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/capture/gps_gate.dart';
import 'package:hulaki/features/track/track_location_settings.dart';
import 'package:hulaki/features/track/track_recorder.dart';

/// Records the breadcrumb trail independent of any screen, so it keeps building
/// while the app is backgrounded (the foreground service keeps the process
/// alive). It never prompts for permission: the map does that, then starts it.
class TrackRecordingController {
  TrackRecordingController({
    required LocalDatabase db,
    required this.ownerId,
  }) : _recorder = TrackRecorder(db);

  final TrackRecorder _recorder;
  final String ownerId;
  StreamSubscription<Position>? _subscription;

  /// Begins recording if permission is already granted and it is not already
  /// running. A no-op otherwise, so callers can call it freely on resume.
  Future<void> start() async {
    if (_subscription != null) return;
    final LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
    } on MissingPluginException {
      // No location platform (tests or an unsupported build): do not record.
      return;
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return;
    }
    _subscription = Geolocator.getPositionStream(
      locationSettings: trackLocationSettings(),
    ).listen(_onPosition);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onPosition(Position position) => _recorder.record(
    ownerId: ownerId,
    fix: GpsFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracyM: position.accuracy,
    ),
    at: DateTime.now(),
  );
}
