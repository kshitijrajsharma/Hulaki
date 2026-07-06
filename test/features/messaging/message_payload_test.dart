import 'package:fieldchat/features/messaging/domain/message_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('altitude and heading survive a JSON round-trip', () {
    const payload = MessagePayload(
      id: 'm1',
      groupId: 'g1',
      senderId: 'u1',
      kind: MessageKind.text,
      createdAtMs: 1000,
      lat: 27.7,
      lng: 85.3,
      accuracyM: 6,
      altitudeM: 1320,
      headingDeg: 47,
    );

    final restored = MessagePayload.fromJson(payload.toJson());

    expect(restored.altitudeM, 1320);
    expect(restored.headingDeg, 47);
  });

  test('a placed point omits altitude and heading', () {
    const payload = MessagePayload(
      id: 'm2',
      groupId: 'g1',
      senderId: 'u1',
      kind: MessageKind.text,
      createdAtMs: 1000,
      lat: 27.7,
      lng: 85.3,
    );

    final json = payload.toJson();

    expect(json.containsKey('altitudeM'), isFalse);
    expect(json.containsKey('headingDeg'), isFalse);
    expect(MessagePayload.fromJson(json).altitudeM, isNull);
  });

  test('an anonymous message carries the flag and omits the name', () {
    const payload = MessagePayload(
      id: 'm3',
      groupId: 'g1',
      senderId: 'u1',
      kind: MessageKind.text,
      createdAtMs: 1000,
      anonymous: true,
    );

    final json = payload.toJson();

    expect(json['anonymous'], isTrue);
    expect(json.containsKey('senderName'), isFalse);
    expect(MessagePayload.fromJson(json).anonymous, isTrue);
  });

  test('a normal message defaults to not anonymous and omits the flag', () {
    const payload = MessagePayload(
      id: 'm4',
      groupId: 'g1',
      senderId: 'u1',
      kind: MessageKind.text,
      createdAtMs: 1000,
      senderName: 'Ada',
    );

    final json = payload.toJson();

    expect(json.containsKey('anonymous'), isFalse);
    expect(MessagePayload.fromJson(json).anonymous, isFalse);
  });
}
