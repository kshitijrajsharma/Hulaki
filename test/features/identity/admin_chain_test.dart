import 'dart:typed_data';

import 'package:fieldchat/features/identity/admin_chain.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a correctly signed event authored by [author].
Future<AdminEvent> signedEvent({
  required String kind,
  required String groupId,
  required String actorId,
  required IdentityKeys author,
  required String subjectId,
  Uint8List? subjectPublic,
}) async {
  final unsigned = AdminEvent(
    kind: kind,
    groupId: groupId,
    actorId: actorId,
    actorPublic: author.signingPublic,
    subjectId: subjectId,
    subjectPublic: subjectPublic,
    signature: Uint8List(0),
  );
  return AdminEvent(
    kind: kind,
    groupId: groupId,
    actorId: actorId,
    actorPublic: author.signingPublic,
    subjectId: subjectId,
    subjectPublic: subjectPublic,
    signature: await author.sign(unsigned.signedBytes()),
  );
}

void main() {
  const groupId = 'g1';

  test('the creator alone is admin with no events', () async {
    final creator = await IdentityKeys.generate();
    final admins = await verifiedAdmins(
      creatorId: 'creator',
      creatorPublic: creator.signingPublic,
      events: const [],
    );
    expect(admins, {'creator'});
  });

  test('an invite the member accepts promotes them', () async {
    final creator = await IdentityKeys.generate();
    final bob = await IdentityKeys.generate();

    final events = [
      await signedEvent(
        kind: 'invite',
        groupId: groupId,
        actorId: 'creator',
        author: creator,
        subjectId: 'bob',
        subjectPublic: bob.signingPublic,
      ),
      await signedEvent(
        kind: 'accept',
        groupId: groupId,
        actorId: 'bob',
        author: bob,
        subjectId: 'bob',
      ),
    ];

    final admins = await verifiedAdmins(
      creatorId: 'creator',
      creatorPublic: creator.signingPublic,
      events: events,
    );
    expect(admins, {'creator', 'bob'});
  });

  test('an invite from a non-admin is ignored', () async {
    final creator = await IdentityKeys.generate();
    final mallory = await IdentityKeys.generate();
    final victim = await IdentityKeys.generate();

    final events = [
      // Mallory is not an admin, so her invite must not take effect.
      await signedEvent(
        kind: 'invite',
        groupId: groupId,
        actorId: 'mallory',
        author: mallory,
        subjectId: 'victim',
        subjectPublic: victim.signingPublic,
      ),
      await signedEvent(
        kind: 'accept',
        groupId: groupId,
        actorId: 'victim',
        author: victim,
        subjectId: 'victim',
      ),
    ];

    final admins = await verifiedAdmins(
      creatorId: 'creator',
      creatorPublic: creator.signingPublic,
      events: events,
    );
    expect(admins, {'creator'});
  });

  test('an accept forged by another key is ignored', () async {
    final creator = await IdentityKeys.generate();
    final bob = await IdentityKeys.generate();
    final imposter = await IdentityKeys.generate();

    final events = [
      await signedEvent(
        kind: 'invite',
        groupId: groupId,
        actorId: 'creator',
        author: creator,
        subjectId: 'bob',
        subjectPublic: bob.signingPublic,
      ),
      // The imposter signs an accept as "bob"; the key does not match the
      // invited key, so it is rejected.
      await signedEvent(
        kind: 'accept',
        groupId: groupId,
        actorId: 'bob',
        author: imposter,
        subjectId: 'bob',
      ),
    ];

    final admins = await verifiedAdmins(
      creatorId: 'creator',
      creatorPublic: creator.signingPublic,
      events: events,
    );
    expect(admins, {'creator'});
  });

  test('a tampered signature is ignored', () async {
    final creator = await IdentityKeys.generate();
    final bob = await IdentityKeys.generate();

    final invite = await signedEvent(
      kind: 'invite',
      groupId: groupId,
      actorId: 'creator',
      author: creator,
      subjectId: 'bob',
      subjectPublic: bob.signingPublic,
    );
    final tampered = AdminEvent(
      kind: invite.kind,
      groupId: invite.groupId,
      actorId: invite.actorId,
      actorPublic: invite.actorPublic,
      subjectId: invite.subjectId,
      subjectPublic: invite.subjectPublic,
      signature: Uint8List.fromList(List<int>.filled(64, 0)),
    );

    final admins = await verifiedAdmins(
      creatorId: 'creator',
      creatorPublic: creator.signingPublic,
      events: [tampered],
    );
    expect(admins, {'creator'});
  });

  test('a promoted admin can promote a third member', () async {
    final creator = await IdentityKeys.generate();
    final bob = await IdentityKeys.generate();
    final carol = await IdentityKeys.generate();

    final events = [
      await signedEvent(
        kind: 'invite',
        groupId: groupId,
        actorId: 'creator',
        author: creator,
        subjectId: 'bob',
        subjectPublic: bob.signingPublic,
      ),
      await signedEvent(
        kind: 'accept',
        groupId: groupId,
        actorId: 'bob',
        author: bob,
        subjectId: 'bob',
      ),
      // Bob, now an admin, invites Carol.
      await signedEvent(
        kind: 'invite',
        groupId: groupId,
        actorId: 'bob',
        author: bob,
        subjectId: 'carol',
        subjectPublic: carol.signingPublic,
      ),
      await signedEvent(
        kind: 'accept',
        groupId: groupId,
        actorId: 'carol',
        author: carol,
        subjectId: 'carol',
      ),
    ];

    final admins = await verifiedAdmins(
      creatorId: 'creator',
      creatorPublic: creator.signingPublic,
      events: events,
    );
    expect(admins, {'creator', 'bob', 'carol'});
  });

  test('an accept with no matching invite is ignored', () async {
    final creator = await IdentityKeys.generate();
    final bob = await IdentityKeys.generate();

    final events = [
      await signedEvent(
        kind: 'accept',
        groupId: groupId,
        actorId: 'bob',
        author: bob,
        subjectId: 'bob',
      ),
    ];

    final admins = await verifiedAdmins(
      creatorId: 'creator',
      creatorPublic: creator.signingPublic,
      events: events,
    );
    expect(admins, {'creator'});
  });
}
