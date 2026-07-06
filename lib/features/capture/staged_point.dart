/// A location chosen by tapping the map, carried back to the chat composer so
/// the next send drops its point here instead of at the live GPS fix.
class StagedPoint {
  const StagedPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}
