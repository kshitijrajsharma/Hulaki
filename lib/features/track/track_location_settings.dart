import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Location settings for continuous breadcrumb recording, tuned so fixes keep
/// arriving while the app is backgrounded. Android relies on the running
/// foreground service to stay exempt from background throttling; iOS needs
/// background updates turned on explicitly and an "Always" permission.
LocationSettings trackLocationSettings() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    // allowBackgroundLocationUpdates and pauseLocationUpdatesAutomatically
    // already default to the values we need (true and false).
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      showBackgroundLocationIndicator: true,
    );
  }
  return AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );
}
