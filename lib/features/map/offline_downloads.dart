import 'package:fieldchat/features/map/offline_areas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide buildFeatureCollection;

/// A group's offline download while it is in flight, with progress from 0 to 1.
class OfflineDownload {
  const OfflineDownload({
    required this.groupId,
    required this.groupName,
    required this.progress,
  });

  final String groupId;
  final String groupName;
  final double progress;
}

/// Tracks offline-region downloads in progress so the Me screen can show a live
/// bar. Finished areas are read separately through [cachedGroupAreas].
class OfflineDownloadsNotifier extends Notifier<List<OfflineDownload>> {
  @override
  List<OfflineDownload> build() => const [];

  /// Starts caching the group's area, streaming progress into state. Completes
  /// when the download finishes; the entry is removed on success or failure.
  Future<void> start({
    required String groupId,
    required String groupName,
    required LatLngBounds bounds,
  }) async {
    if (state.any((d) => d.groupId == groupId)) return;
    _put(groupId: groupId, groupName: groupName, progress: 0);
    try {
      await cacheGroupOffline(
        groupId: groupId,
        groupName: groupName,
        bounds: bounds,
        onProgress: (fraction) =>
            _put(groupId: groupId, groupName: groupName, progress: fraction),
      );
    } finally {
      _remove(groupId);
    }
  }

  void _put({
    required String groupId,
    required String groupName,
    required double progress,
  }) {
    state = [
      for (final d in state)
        if (d.groupId != groupId) d,
      OfflineDownload(
        groupId: groupId,
        groupName: groupName,
        progress: progress,
      ),
    ];
  }

  void _remove(String groupId) {
    state = [
      for (final d in state)
        if (d.groupId != groupId) d,
    ];
  }
}

final offlineDownloadsProvider =
    NotifierProvider<OfflineDownloadsNotifier, List<OfflineDownload>>(
      OfflineDownloadsNotifier.new,
    );
