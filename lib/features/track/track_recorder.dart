import 'package:hulaki/core/geo.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/capture/gps_gate.dart';

/// Keeps the user's breadcrumb trail. Records a point once they have moved a
/// meaningful distance from the last one, so a stationary phone does not fill
/// the trail. The bar is the larger of [minDistanceM] and the fix's own
/// accuracy, so a wandering fix in poor signal reads as noise, not movement.
/// Reading the trail purges anything older than [retention].
class TrackRecorder {
  TrackRecorder(
    this._db, {
    this.minDistanceM = 10,
    this.retention = const Duration(hours: 24),
  });

  final LocalDatabase _db;
  final double minDistanceM;
  final Duration retention;

  double? _lastLat;
  double? _lastLng;

  /// Stores [fix] if it is the first point or far enough from the last.
  /// Returns whether a point was written.
  Future<bool> record({
    required String ownerId,
    required GpsFix fix,
    required DateTime at,
  }) async {
    final lastLat = _lastLat;
    final lastLng = _lastLng;
    if (lastLat != null && lastLng != null) {
      final moved = distanceMeters(lastLat, lastLng, fix.lat, fix.lng);
      final threshold = fix.accuracyM > minDistanceM
          ? fix.accuracyM
          : minDistanceM;
      if (moved < threshold) return false;
    }

    await _db
        .into(_db.trackPoints)
        .insert(
          TrackPointsCompanion.insert(
            ownerId: ownerId,
            lat: fix.lat,
            lng: fix.lng,
            accuracyM: fix.accuracyM,
            recordedAt: at,
          ),
        );
    _lastLat = fix.lat;
    _lastLng = fix.lng;
    return true;
  }

  /// The trail to draw: points within [retention], oldest first. Older points
  /// are purged first.
  Future<List<TrackPoint>> visibleTrack({
    required String ownerId,
    required DateTime now,
  }) async {
    final cutoff = now.subtract(retention);
    await _db.purgeTrackBefore(ownerId, cutoff);
    return _db.trackSince(ownerId, cutoff);
  }
}
