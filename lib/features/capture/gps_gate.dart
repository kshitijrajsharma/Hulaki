import 'dart:async';

/// A single GPS reading. Altitude comes from the fix; heading is the device
/// compass facing at capture time, so both are absent for map-placed points.
class GpsFix {
  const GpsFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    this.altitudeM,
    this.headingDeg,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final double? altitudeM;
  final double? headingDeg;
}

/// The location committed to a capture. [pending] means no fix arrived in
/// time; the point is sent as "location pending" and pinned when GPS returns.
class GeoResult {
  GeoResult.fix(GpsFix fix)
    : lat = fix.lat,
      lng = fix.lng,
      accuracyM = fix.accuracyM,
      altitudeM = fix.altitudeM,
      headingDeg = fix.headingDeg,
      pending = false;

  const GeoResult.pending()
    : lat = null,
      lng = null,
      accuracyM = null,
      altitudeM = null,
      headingDeg = null,
      pending = true;

  /// A point placed by tapping the map. It is located but carries no accuracy,
  /// altitude, or heading, since it is not a measured GPS fix.
  const GeoResult.placed(double this.lat, double this.lng)
    : accuracyM = null,
      altitudeM = null,
      headingDeg = null,
      pending = false;

  final double? lat;
  final double? lng;
  final double? accuracyM;
  final double? altitudeM;
  final double? headingDeg;
  final bool pending;
}

/// Locks the spot fast, then sharpens if it can. On capture it takes the first
/// fix immediately so nothing is lost, keeps listening until accuracy reaches
/// the target or the wait caps out, then commits the best fix seen. No fix at
/// all commits as pending.
class GpsGate {
  const GpsGate({
    this.targetAccuracyM = 8,
    this.maxWait = const Duration(seconds: 4),
  });

  final double targetAccuracyM;
  final Duration maxWait;

  Future<GeoResult> acquire(Stream<GpsFix> fixes) {
    final completer = Completer<GeoResult>();
    GpsFix? best;
    Timer? capTimer;
    late StreamSubscription<GpsFix> subscription;

    void finish() {
      if (completer.isCompleted) return;
      capTimer?.cancel();
      unawaited(subscription.cancel());
      completer.complete(
        best == null ? const GeoResult.pending() : GeoResult.fix(best!),
      );
    }

    subscription = fixes.listen(
      (fix) {
        if (best == null || fix.accuracyM < best!.accuracyM) best = fix;
        if (best!.accuracyM <= targetAccuracyM) finish();
      },
      onDone: finish,
    );
    capTimer = Timer(maxWait, finish);

    return completer.future;
  }
}
