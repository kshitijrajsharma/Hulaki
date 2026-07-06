import 'package:fieldchat/core/geo.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/capture/gps_gate.dart';

/// Keeps the user's breadcrumb trail. Records a point once they have moved at
/// least [minDistanceM] from the last one, so a stationary phone does not fill
/// the trail. Reading the trail purges anything older than 24 hours.
class TrackRecorder {
  TrackRecorder(this._db, {this.minDistanceM = 10});

  final LocalDatabase _db;
  final double minDistanceM;

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
      if (moved < minDistanceM) return false;
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

  /// The trail to draw: points from the last 24 hours, oldest first. Older
  /// points are purged first.
  Future<List<TrackPoint>> visibleTrack({
    required String ownerId,
    required DateTime now,
  }) async {
    final cutoff = now.subtract(const Duration(hours: 24));
    await _db.purgeTrackBefore(ownerId, cutoff);
    return _db.trackSince(ownerId, cutoff);
  }
}
