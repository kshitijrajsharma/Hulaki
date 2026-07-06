import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/messaging/domain/message_payload.dart';
import 'package:xml/xml.dart';

/// Builds a GPX 1.1 document: one waypoint per located message (named by its
/// tag, described by its text) plus the optional breadcrumb track. Opens in
/// QGIS, OsmAnd and Garmin.
String buildGpx({
  required String name,
  required List<Message> messages,
  required List<HotKey> hotKeys,
  List<TrackPoint> track = const [],
}) {
  final labels = {for (final h in hotKeys) h.id: h.label};
  final icons = {for (final h in hotKeys) h.id: h.iconName};
  final builder = XmlBuilder()
    ..processing('xml', 'version="1.0" encoding="UTF-8"');

  builder.element(
    'gpx',
    attributes: {
      'version': '1.1',
      'creator': 'FieldChat',
      'xmlns': 'http://www.topografix.com/GPX/1/1',
    },
    nest: () {
      builder.element(
        'metadata',
        nest: () => builder.element('name', nest: name),
      );

      for (final message in messages) {
        if (message.deletedAt != null) continue;
        if (message.kind == MessageKind.groupMeta.name) continue;
        if (message.lat == null || message.lng == null) continue;

        builder.element(
          'wpt',
          attributes: {
            'lat': message.lat!.toString(),
            'lon': message.lng!.toString(),
          },
          nest: () {
            final label = message.tagId == null ? null : labels[message.tagId];
            if (label != null) builder.element('name', nest: label);
            final desc = message.body;
            if (desc != null) builder.element('desc', nest: desc);
            final sym = message.tagId == null ? null : icons[message.tagId];
            if (sym != null) builder.element('sym', nest: sym);
            builder.element(
              'time',
              nest: message.createdAt.toUtc().toIso8601String(),
            );
          },
        );
      }

      if (track.isNotEmpty) {
        builder.element(
          'trk',
          nest: () {
            builder
              ..element('name', nest: '$name track')
              ..element(
                'trkseg',
                nest: () {
                  for (final point in track) {
                    builder.element(
                      'trkpt',
                      attributes: {
                        'lat': point.lat.toString(),
                        'lon': point.lng.toString(),
                      },
                      nest: () => builder.element(
                        'time',
                        nest: point.recordedAt.toUtc().toIso8601String(),
                      ),
                    );
                  }
                },
              );
          },
        );
      }
    },
  );

  return builder.buildDocument().toXmlString(pretty: true);
}
