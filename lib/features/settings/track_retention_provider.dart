import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';

const _trackRetentionKey = 'settings.trackRetentionDays';

/// Days of background trail the user chooses to keep. Only these values are
/// offered; anything stored outside the set falls back to the default.
const trackRetentionDayChoices = [1, 2, 4, 7];

/// How long the breadcrumb trail is retained and drawn, persisted on the
/// device as a whole number of days. Defaults to one day (24 hours).
class TrackRetentionNotifier extends Notifier<Duration> {
  @override
  Duration build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getInt(_trackRetentionKey);
    final days = trackRetentionDayChoices.contains(stored) ? stored! : 1;
    return Duration(days: days);
  }

  Future<void> setDays(int days) async {
    state = Duration(days: days);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_trackRetentionKey, days);
  }
}

final trackRetentionProvider =
    NotifierProvider<TrackRetentionNotifier, Duration>(
      TrackRetentionNotifier.new,
    );
