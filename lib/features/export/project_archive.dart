import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/export/geojson.dart';
import 'package:fieldchat/features/export/gpx.dart';

/// Resolves the decrypted bytes of a media item by id, or null if absent.
typedef MediaResolver = Future<Uint8List?> Function(String mediaId);

/// Builds a self-contained project bundle (a .zip) for a group: the points as
/// GeoJSON with relative media paths, the area, the track, a manifest, and the
/// media files themselves. It opens in QGIS and travels offline.
///
/// Media is read decrypted from the local store: an export is a deliberate
/// "take my data out" action, so the bundle is plaintext.
Future<Uint8List> buildProjectArchive({
  required Group group,
  required List<HotKey> hotKeys,
  required List<Message> messages,
  required MediaResolver mediaResolver,
  List<TrackPoint> track = const [],
  DateTime? exportedAt,
}) async {
  final stamp = exportedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final archive = Archive();

  final mediaPaths = <String, String>{};
  var mediaCount = 0;
  for (final message in messages) {
    final mediaId = message.mediaId;
    if (mediaId == null || message.deletedAt != null) continue;
    if (mediaPaths.containsKey(mediaId)) continue;
    final bytes = await mediaResolver(mediaId);
    if (bytes == null) continue;
    final path = 'media/$mediaId.${_extensionForMime(message.mediaMime)}';
    mediaPaths[mediaId] = path;
    _addBytes(archive, path, bytes);
    mediaCount++;
  }

  final featureCollection = buildFeatureCollection(
    messages,
    hotKeys,
    mediaPaths: mediaPaths,
  );
  final pointCount = (featureCollection['features'] as List).length;
  _addText(
    archive,
    'data.geojson',
    featureCollectionToString(featureCollection),
  );

  if (group.aoiGeoJson != null) {
    _addText(archive, 'aoi.geojson', group.aoiGeoJson!);
  }

  if (track.isNotEmpty) {
    _addText(
      archive,
      'track.gpx',
      buildGpx(
        name: group.name,
        messages: messages,
        hotKeys: hotKeys,
        track: track,
      ),
    );
  }

  final manifest = {
    'app': 'FieldChat',
    'formatVersion': 1,
    'group': {'id': group.id, 'name': group.name},
    'exportedAt': stamp.toUtc().toIso8601String(),
    'counts': {'points': pointCount, 'media': mediaCount},
    'hotKeys': [
      for (final h in hotKeys)
        {'label': h.label, 'color': _hexColor(h.colorValue)},
    ],
    'files': {
      'data': 'data.geojson',
      if (group.aoiGeoJson != null) 'aoi': 'aoi.geojson',
      if (track.isNotEmpty) 'track': 'track.gpx',
    },
  };
  _addText(
    archive,
    'project.json',
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  _addText(archive, 'README.txt', _readme(group.name));

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void _addText(Archive archive, String name, String content) =>
    _addBytes(archive, name, Uint8List.fromList(utf8.encode(content)));

void _addBytes(Archive archive, String name, Uint8List bytes) =>
    archive.addFile(ArchiveFile(name, bytes.length, bytes));

String _extensionForMime(String? mime) => switch (mime) {
  'image/jpeg' => 'jpg',
  'image/png' => 'png',
  'image/webp' => 'webp',
  'video/mp4' => 'mp4',
  'audio/mp4' || 'audio/m4a' => 'm4a',
  'audio/aac' => 'aac',
  'audio/ogg' => 'ogg',
  _ => 'bin',
};

String _hexColor(int argb) {
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '#${rgb.toUpperCase()}';
}

String _readme(String groupName) =>
    'FieldChat project export: $groupName\n\n'
    'data.geojson  Points with tag, sender, time, accuracy and caption.\n'
    '              Photo/video/audio points link to files under media/.\n'
    'aoi.geojson   The mapping area, if one was set.\n'
    'track.gpx     The recorded track, if any.\n'
    'media/        The photos, videos and voice notes.\n\n'
    'Open data.geojson in QGIS or any GeoJSON viewer. The media paths are '
    'relative, so keep this folder together.\n';
