import 'dart:convert';
import 'dart:typed_data';

import 'package:hulaki/data/local/database.dart';
import 'package:image/image.dart' as img;

/// The largest edge a snapshot photo keeps, so images stay readable in the web
/// viewer without bloating each object.
const _maxPhotoEdge = 1000;

/// A built snapshot: the small JSON [data] describing points and tags, plus the
/// downscaled [photos] keyed by point id. Photos are stored as separate objects
/// and fetched lazily, so a thousand-point snapshot stays a small download.
class SharedSnapshot {
  SharedSnapshot(this.data, this.photos);

  final Map<String, dynamic> data;
  final Map<String, Uint8List> photos;
}

/// Builds the data a shared web snapshot carries: a standard GeoJSON of the
/// points (each tag's colour and icon attached, no author identity), a legend
/// of the tags used, and the downscaled photos to upload alongside. Names are
/// never included, so the public page cannot reveal who mapped a point.
Future<SharedSnapshot> buildSharedSnapshot({
  required String groupName,
  required List<Message> messages,
  required List<HotKey> hotKeys,
  required Map<String, Uint8List> mediaBytes,
  required DateTime generatedAt,
}) async {
  final labels = {for (final h in hotKeys) h.id: h.label};
  final colors = {for (final h in hotKeys) h.id: _hex(h.colorValue)};
  final icons = {for (final h in hotKeys) h.id: h.iconName};

  final features = <Map<String, dynamic>>[];
  final photos = <String, Uint8List>{};
  final usedTagIds = <String>{};

  for (final message in messages) {
    if (message.deletedAt != null) continue;
    if (message.lat == null || message.lng == null) continue;

    final tagId = message.tagId;
    if (tagId != null) usedTagIds.add(tagId);

    var hasPhoto = false;
    final mediaId = message.mediaId;
    if (mediaId != null) {
      final bytes = mediaBytes[mediaId];
      if (bytes != null) {
        final jpeg = _downscaleToJpeg(bytes);
        if (jpeg != null) {
          photos[message.id] = jpeg;
          hasPhoto = true;
        }
      }
    }

    final properties = <String, dynamic>{
      'id': message.id,
      'tag': tagId == null ? null : labels[tagId],
      'color': tagId == null ? null : colors[tagId],
      'icon': tagId == null ? null : icons[tagId],
      'note': message.body,
      'time': message.createdAt.toUtc().toIso8601String(),
      'accuracyM': message.accuracyM,
      'heading': message.headingDeg,
      'photo': hasPhoto,
    }..removeWhere((_, value) => value == null || value == false);

    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [message.lng, message.lat],
      },
      'properties': properties,
    });
  }

  final legend = [
    for (final h in hotKeys)
      if (usedTagIds.contains(h.id))
        {'label': h.label, 'color': _hex(h.colorValue), 'icon': h.iconName},
  ];

  final data = {
    'meta': {
      'app': 'Hulaki',
      'group': groupName,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'count': features.length,
    },
    'legend': legend,
    'geojson': {'type': 'FeatureCollection', 'features': features},
  };
  return SharedSnapshot(data, photos);
}

/// Encodes a snapshot payload to UTF-8 JSON bytes, ready to encrypt.
Uint8List snapshotToBytes(Map<String, dynamic> snapshot) =>
    Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));

String _hex(int value) {
  final rgb = value & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Downscales an image to a readable size and re-encodes it as JPEG bytes.
/// Returns null when the bytes are not a decodable image.
Uint8List? _downscaleToJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final longest = decoded.width >= decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longest > _maxPhotoEdge
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? _maxPhotoEdge : null,
          height: decoded.height > decoded.width ? _maxPhotoEdge : null,
        )
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
}
