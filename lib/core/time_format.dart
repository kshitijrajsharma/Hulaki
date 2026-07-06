import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

bool _shortRegistered = false;

void _ensureShortLocale() {
  if (_shortRegistered) return;
  timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
  _shortRegistered = true;
}

/// A compact relative label for a past time: "now", "3m", "2h", "5d".
String relativeTime(DateTime when, {DateTime? now}) {
  _ensureShortLocale();
  return timeago.format(
    when,
    locale: 'en_short',
    clock: now ?? DateTime.now(),
  );
}

/// A relative label as a sentence fragment: "just now" or "3m ago".
String relativePhrase(DateTime when, {DateTime? now}) {
  final label = relativeTime(when, now: now);
  return label == 'now' ? 'just now' : '$label ago';
}

/// The full local timestamp shown when a relative label is tapped.
String exactTime(DateTime when) =>
    DateFormat('MMM d, y · HH:mm').format(when.toLocal());
