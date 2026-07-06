import 'dart:convert';
import 'dart:typed_data';

import 'package:fieldchat/features/identity/identity_crypto.dart';

/// A signed admin control event exchanged in the group channel. Two kinds form
/// the promotion handshake: an existing admin `invite`s a member, and that
/// member `accept`s. Both are signed by their author, so neither can be forged
/// by any other member.
class AdminEvent {
  const AdminEvent({
    required this.kind,
    required this.groupId,
    required this.actorId,
    required this.actorPublic,
    required this.subjectId,
    required this.signature,
    this.subjectPublic,
  });

  /// 'invite' or 'accept'.
  final String kind;
  final String groupId;

  /// The author of this event (the envelope sender).
  final String actorId;

  /// The author's signing public key, as claimed by the event.
  final Uint8List actorPublic;

  /// invite: the invited member. accept: the accepter (equal to [actorId]).
  final String subjectId;

  /// invite: the invited member's signing public key. accept: null.
  final Uint8List? subjectPublic;

  final Uint8List signature;

  /// The exact bytes the author signs, so a signature binds every field.
  List<int> signedBytes() => utf8.encode(
    [
      kind,
      groupId,
      actorId,
      subjectId,
      if (subjectPublic == null) '' else base64Encode(subjectPublic!),
    ].join('|'),
  );
}

/// Derives the verified admin set from the pinned creator key and the admin
/// events. Admission requires a valid invite signed by a current admin and an
/// accept signed by exactly the invited key, so the set is rooted in the
/// creator and cannot be extended by any other member. Events are resolved to a
/// fixpoint, so the result does not depend on the order they are stored in.
Future<Set<String>> verifiedAdmins({
  required String creatorId,
  required Uint8List creatorPublic,
  required List<AdminEvent> events,
}) async {
  // Verify every signature once; an event with a bad signature is discarded.
  final valid = <AdminEvent>[];
  for (final event in events) {
    if (event.actorPublic.isEmpty) continue;
    final ok = await IdentityKeys.verify(
      event.signedBytes(),
      signature: event.signature,
      signerPublic: event.actorPublic,
    );
    if (ok) valid.add(event);
  }

  final admins = <String>{creatorId};
  final adminKeys = <String, Uint8List>{creatorId: creatorPublic};
  final invited = <String, Uint8List>{};

  var changed = true;
  while (changed) {
    changed = false;
    for (final event in valid) {
      switch (event.kind) {
        case 'invite':
          final knownKey = adminKeys[event.actorId];
          final actorIsAdmin =
              knownKey != null && _sameBytes(knownKey, event.actorPublic);
          final subjectPublic = event.subjectPublic;
          if (actorIsAdmin &&
              subjectPublic != null &&
              !invited.containsKey(event.subjectId)) {
            invited[event.subjectId] = subjectPublic;
            changed = true;
          }
        case 'accept':
          final invitedKey = invited[event.actorId];
          if (invitedKey != null &&
              _sameBytes(invitedKey, event.actorPublic) &&
              !admins.contains(event.actorId)) {
            admins.add(event.actorId);
            adminKeys[event.actorId] = event.actorPublic;
            changed = true;
          }
      }
    }
  }

  return admins;
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
