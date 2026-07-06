import 'dart:convert';

import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/messaging/domain/message_payload.dart';

/// Builds the GeoJSON FeatureCollection that is both the map's pin source and
/// the export format. One Point feature per located, non-deleted message,
/// carrying its tag, sender, time, accuracy, text/caption and media id.
/// [mediaPaths] maps a message media id to a relative path inside a project
/// bundle (for example `media/<id>.jpg`); when supplied, located messages with
/// media gain a `media` property pointing at the bundled file.
Map<String, dynamic> buildFeatureCollection(
  List<Message> messages,
  List<HotKey> hotKeys, {
  Map<String, String>? mediaPaths,
}) {
  final labels = {for (final h in hotKeys) h.id: h.label};
  final icons = {for (final h in hotKeys) h.id: h.iconName};
  final features = <Map<String, dynamic>>[];

  for (final message in messages) {
    if (message.deletedAt != null) continue;
    if (message.kind == MessageKind.groupMeta.name) continue;
    if (message.lat == null || message.lng == null) continue;

    final properties = <String, dynamic>{
      'id': message.id,
      'kind': message.kind,
      'tag': message.tagId == null ? null : labels[message.tagId],
      'tagId': message.tagId,
      'icon': message.tagId == null ? null : icons[message.tagId],
      'sender': message.senderId,
      'time': message.createdAt.toUtc().toIso8601String(),
      'accuracyM': message.accuracyM,
      'text': message.body,
      'mediaId': message.mediaId,
      'media': message.mediaId == null ? null : mediaPaths?[message.mediaId],
    }..removeWhere((_, value) => value == null);

    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [message.lng, message.lat],
      },
      'properties': properties,
    });
  }

  return {'type': 'FeatureCollection', 'features': features};
}

String featureCollectionToString(Map<String, dynamic> collection) =>
    const JsonEncoder.withIndent('  ').convert(collection);

/// Bounding box [minLng, minLat, maxLng, maxLat] of a GeoJSON area, or null
/// when it carries no coordinates. Frames and validates a group's area.
List<double>? aoiBounds(String? geoJson) {
  if (geoJson == null) return null;
  final coords = <List<double>>[];
  _collectCoordinates(jsonDecode(geoJson), coords);
  if (coords.isEmpty) return null;

  var minLng = coords.first[0];
  var minLat = coords.first[1];
  var maxLng = coords.first[0];
  var maxLat = coords.first[1];
  for (final point in coords) {
    minLng = point[0] < minLng ? point[0] : minLng;
    minLat = point[1] < minLat ? point[1] : minLat;
    maxLng = point[0] > maxLng ? point[0] : maxLng;
    maxLat = point[1] > maxLat ? point[1] : maxLat;
  }
  return [minLng, minLat, maxLng, maxLat];
}

/// Whether [lat]/[lng] falls inside the GeoJSON area, testing the exterior
/// ring of every polygon it contains. False when the area holds no polygon.
bool pointInAoi(String geoJson, double lat, double lng) {
  final rings = <List<List<double>>>[];
  _collectPolygonRings(jsonDecode(geoJson), rings);
  for (final ring in rings) {
    if (_ringContains(ring, lng, lat)) return true;
  }
  return false;
}

void _collectPolygonRings(Object? node, List<List<List<double>>> into) {
  if (node is Map) {
    final coords = node['coordinates'];
    if (node['type'] == 'Polygon' && coords is List && coords.isNotEmpty) {
      into.add(_ringOf(coords.first));
    } else if (node['type'] == 'MultiPolygon' && coords is List) {
      for (final polygon in coords) {
        if (polygon is List && polygon.isNotEmpty) {
          into.add(_ringOf(polygon[0]));
        }
      }
    }
    for (final value in node.values) {
      _collectPolygonRings(value, into);
    }
  } else if (node is List) {
    for (final child in node) {
      _collectPolygonRings(child, into);
    }
  }
}

List<List<double>> _ringOf(Object? ring) => [
  if (ring is List)
    for (final point in ring)
      if (point is List &&
          point.length >= 2 &&
          point[0] is num &&
          point[1] is num)
        [(point[0] as num).toDouble(), (point[1] as num).toDouble()],
];

/// Ray-casting test: whether [x]/[y] (lng/lat) lies within the closed [ring].
bool _ringContains(List<List<double>> ring, double x, double y) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final (xi, yi) = (ring[i][0], ring[i][1]);
    final (xj, yj) = (ring[j][0], ring[j][1]);
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

void _collectCoordinates(Object? node, List<List<double>> into) {
  if (node is List) {
    if (node.length >= 2 && node[0] is num && node[1] is num) {
      into.add([(node[0] as num).toDouble(), (node[1] as num).toDouble()]);
    } else {
      for (final child in node) {
        _collectCoordinates(child, into);
      }
    }
  } else if (node is Map) {
    for (final value in node.values) {
      _collectCoordinates(value, into);
    }
  }
}
