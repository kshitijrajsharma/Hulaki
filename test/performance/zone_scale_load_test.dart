import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/features/capture/gps_gate.dart';
import 'package:hulaki/features/export/geojson.dart';
import 'package:hulaki/features/sync/blob_store.dart';
import 'package:hulaki/features/sync/in_memory_transport.dart';
import 'package:hulaki/features/zones/domain/zone.dart';
import 'package:hulaki/features/zones/domain/zone_bucketing.dart';
import 'package:hulaki/features/zones/domain/zone_partition.dart';

import '../integration/admin_handshake_test.dart';

const _palette = [
  0xFF111111,
  0xFF222222,
  0xFF333333,
  0xFF444444,
  0xFF555555,
  0xFF666666,
  0xFF777777,
  0xFF888888,
  0xFF999999,
  0xFFAAAAAA,
  0xFFBBBBBB,
  0xFFCCCCCC,
];

String _aoi() => jsonEncode({
  'type': 'Feature',
  'geometry': {
    'type': 'Polygon',
    'coordinates': [
      [
        [85.30, 27.70],
        [85.33, 27.70],
        [85.33, 27.73],
        [85.30, 27.73],
        [85.30, 27.70],
      ],
    ],
  },
});

(double, double) _centre(Zone zone) {
  var minLng = 180.0;
  var minLat = 90.0;
  var maxLng = -180.0;
  var maxLat = -90.0;
  for (final ring in zone.pieces) {
    for (final point in ring) {
      minLng = point[0] < minLng ? point[0] : minLng;
      maxLng = point[0] > maxLng ? point[0] : maxLng;
      minLat = point[1] < minLat ? point[1] : minLat;
      maxLat = point[1] > maxLat ? point[1] : maxLat;
    }
  }
  return ((minLat + maxLat) / 2, (minLng + maxLng) / 2);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    '100 mappers across zones: sync, coverage and export hold',
    () async {
      final transport = InMemoryTransport();
      final blobs = InMemoryBlobStore();
      final admin = Device('admin', transport, blobs);
      final sender = Device('sender', transport, blobs);
      await admin.init();
      await sender.init();
      addTearDown(() async {
        await admin.dispose();
        await sender.dispose();
        await transport.dispose();
      });

      final group = await admin.groups.createGroup(
        name: 'Ward 7',
        identity: admin.identity,
        hotKeys: const [],
      );
      await sender.groups.joinViaLink(
        admin.groups.inviteLinkFor(group),
        sender.identity,
      );
      await waitFor(
        () async => (await admin.db.profileById('sender'))?.signingKey != null,
      );
      await admin.groups.setMappingArea(group.id, _aoi());
      final zones = gridSplit(_aoi(), 9, palette: _palette);
      expect(zones.length, greaterThanOrEqualTo(9));
      await admin.groups.setZones(group.id, zones);
      await waitFor(() async {
        final group0 = await sender.db.groupById(group.id);
        return zonesFromGeoJson(group0?.zonesGeoJson).length == zones.length;
      });

      final centres = [for (final zone in zones) _centre(zone)];
      final watch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        final (lat, lng) = centres[i % centres.length];
        await sender.sync.sendText(
          groupId: group.id,
          text: 'p$i',
          geo: GeoResult.fix(GpsFix(lat: lat, lng: lng, accuracyM: 5)),
        );
      }
      await waitFor(() async {
        final rows = await admin.db.messagesFor(group.id);
        return rows.where((m) => (m.body ?? '').startsWith('p')).length >= 100;
      }, tries: 60000);
      watch.stop();

      for (var i = 0; i < 100; i++) {
        await admin.db.setAssignedZone(
          group.id,
          'm$i',
          zones[i % zones.length].id,
        );
      }

      final adminZones = zonesFromGeoJson(
        (await admin.db.groupById(group.id))!.zonesGeoJson,
      );
      final located = [
        for (final m in await admin.db.messagesFor(group.id))
          if (m.lat != null && m.lng != null) (lat: m.lat!, lng: m.lng!),
      ];
      final counts = countsByZone(adminZones, located);
      expect(counts.values.fold(0, (a, b) => a + b), 100);
      expect(counts.values.every((c) => c > 0), isTrue);

      final members = await admin.db.watchMembersFor(group.id).first;
      expect(
        members.where((m) => m.assignedZoneId != null).length,
        greaterThanOrEqualTo(100),
      );

      final collection = buildFeatureCollection(
        await admin.db.messagesFor(group.id),
        const [],
      );
      final features = collection['features'] as List;
      expect(features.length, greaterThanOrEqualTo(100));

      // Surfacing the timing is the point of a load check.
      // ignore: avoid_print
      print(
        'Zones scale: 100 points synced and bucketed across ${zones.length} '
        'zones in ${watch.elapsedMilliseconds} ms; export ${features.length} '
        'features',
      );
    },
    tags: 'load',
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
