import 'dart:convert';
import 'dart:typed_data';

import 'package:fieldchat/features/discovery/public_directory.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PublicGroup at(String id, double lat, double lng) => PublicGroup(
    groupId: id,
    name: id,
    centerLat: lat,
    centerLng: lng,
    encKey: 'k',
  );

  test('nearby returns groups inside the radius, nearest first', () async {
    final dir = InMemoryPublicDirectory();
    await dir.publish(at('here', 27.7000, 85.3000));
    await dir.publish(at('close', 27.7100, 85.3000)); // ~1.1 km
    await dir.publish(at('far', 28.5000, 85.3000)); // ~89 km

    final near = await dir.nearby(lat: 27.70, lng: 85.30);

    expect(near.map((g) => g.groupId), ['here', 'close']);
    expect(near.first.distanceM, lessThan(near.last.distanceM!));
  });

  test('searchByName matches case-insensitively, ignoring distance', () async {
    final dir = InMemoryPublicDirectory();
    await dir.publish(at('Riverside cleanup', 27.70, 85.30));
    await dir.publish(at('River survey', 40.5, 20.5)); // far away
    await dir.publish(at('Forest watch', 27.70, 85.30));

    final found = await dir.searchByName('river');

    expect(
      found.map((g) => g.groupId),
      ['River survey', 'Riverside cleanup'],
    );
  });

  test('searchByName returns nothing for a blank query', () async {
    final dir = InMemoryPublicDirectory();
    await dir.publish(at('Anything', 27.70, 85.30));
    expect(await dir.searchByName('   '), isEmpty);
  });

  test('remove takes a group out of the directory', () async {
    final dir = InMemoryPublicDirectory();
    await dir.publish(at('g', 27.70, 85.30));
    await dir.remove('g');
    final near = await dir.nearby(lat: 27.70, lng: 85.30);
    expect(near, isEmpty);
  });

  test('preview fields survive publish and nearby with distance', () async {
    final dir = InMemoryPublicDirectory();
    await dir.publish(
      const PublicGroup(
        groupId: 'g',
        name: 'Riverside',
        centerLat: 27.70,
        centerLng: 85.30,
        encKey: 'k',
        memberCount: 3,
        aoiGeoJson: '{"type":"Polygon"}',
        tags: [
          DirectoryTag(label: 'Bin', colorValue: 42, iconName: 'delete'),
        ],
      ),
    );

    final found = (await dir.nearby(lat: 27.70, lng: 85.30)).single;

    expect(found.memberCount, 3);
    expect(found.aoiGeoJson, '{"type":"Polygon"}');
    expect(found.tags.single.label, 'Bin');
    expect(found.tags.single.iconName, 'delete');
    expect(found.distanceM, isNotNull);
  });

  test('a directory tag survives a JSON round-trip', () {
    const tag = DirectoryTag(label: 'Light', colorValue: 7, iconName: 'bolt');
    final restored = DirectoryTag.fromJson(tag.toJson());
    expect(restored.label, 'Light');
    expect(restored.colorValue, 7);
    expect(restored.iconName, 'bolt');
  });

  test(
    'approving a join request delivers the key sealed to the requester',
    () async {
      final dir = InMemoryPublicDirectory();
      final requester = await IdentityKeys.generate();
      final groupKey = Uint8List.fromList(List<int>.generate(32, (i) => i));

      await dir.requestJoin(
        JoinRequest(
          id: 'r1',
          groupId: 'g',
          requesterId: 'u',
          requesterName: 'Passerby',
          signingKey: base64Encode(requester.signingPublic),
          agreementKey: base64Encode(requester.agreementPublic),
        ),
      );
      expect((await dir.pendingRequests('g')).length, 1);

      // The admin seals the group key to the requester and approves.
      final sealed = await IdentityKeys.seal(
        groupKey,
        recipientAgreementPublic: requester.agreementPublic,
      );
      await dir.approveRequest('r1', jsonEncode(sealed));

      // The request is no longer pending, and only the requester can open it.
      expect(await dir.pendingRequests('g'), isEmpty);
      final mine = await dir.myRequest('g', 'u');
      expect(mine!.sealedKey, isNotNull);
      final box = (jsonDecode(mine.sealedKey!) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
      expect(await requester.open(box), groupKey);
    },
  );
}
