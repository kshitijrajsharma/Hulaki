import 'dart:convert';
import 'dart:typed_data';

import 'package:fieldchat/features/sync/signal_group_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _group = 'ward7-litter';

Uint8List _text(String value) => Uint8List.fromList(utf8.encode(value));

/// Shares [from]'s sender key to [to] over a pairwise X3DH session, asserting
/// the key travels only as ciphertext.
Future<void> _shareKey(SignalMember from, SignalMember to) async {
  final distribution = await from.createSenderKey(_group);
  await from.startSession(to.address, await to.publishBundle());
  final wire = await from.encryptPairwise(to.address, distribution);
  expect(wire.bytes, isNot(equals(distribution)));
  final received = await to.decryptPairwise(from.address, wire);
  expect(received, equals(distribution));
  await to.processSenderKey(_group, from.address, received);
}

void main() {
  test('members read group messages after sender keys are shared', () async {
    final asha = SignalMember('asha');
    final bob = SignalMember('bob');
    final carol = SignalMember('carol');

    await _shareKey(asha, bob);
    await _shareKey(asha, carol);

    final cipher = await asha.encryptGroup(_group, _text('Overflowing bin'));
    expect(
      utf8.decode(await bob.decryptGroup(_group, asha.address, cipher)),
      'Overflowing bin',
    );
    expect(
      utf8.decode(await carol.decryptGroup(_group, asha.address, cipher)),
      'Overflowing bin',
    );
  });

  test('the ratchet advances: each message has fresh ciphertext', () async {
    final asha = SignalMember('asha');
    final bob = SignalMember('bob');
    await _shareKey(asha, bob);

    final first = await asha.encryptGroup(_group, _text('one'));
    final second = await asha.encryptGroup(_group, _text('two'));
    expect(first, isNot(equals(second)));
    expect(
      utf8.decode(await bob.decryptGroup(_group, asha.address, first)),
      'one',
    );
    expect(
      utf8.decode(await bob.decryptGroup(_group, asha.address, second)),
      'two',
    );
  });

  test('a non-member cannot decrypt group messages', () async {
    final asha = SignalMember('asha');
    final bob = SignalMember('bob');
    final dave = SignalMember('dave');
    await _shareKey(asha, bob);

    final cipher = await asha.encryptGroup(_group, _text('secret'));
    await expectLater(
      dave.decryptGroup(_group, asha.address, cipher),
      throwsA(anything),
    );
  });

  test('removing a member locks them out of future messages', () async {
    final asha = SignalMember('asha');
    final bob = SignalMember('bob');
    final carol = SignalMember('carol');
    await _shareKey(asha, bob);
    await _shareKey(asha, carol);

    final before = await asha.encryptGroup(_group, _text('before removal'));
    expect(
      utf8.decode(await carol.decryptGroup(_group, asha.address, before)),
      'before removal',
    );

    // Remove Carol: rotate the sender key, redistribute only to Bob.
    await asha.rotateSenderKey(_group);
    await _shareKey(asha, bob);

    final after = await asha.encryptGroup(_group, _text('after removal'));
    expect(
      utf8.decode(await bob.decryptGroup(_group, asha.address, after)),
      'after removal',
    );
    await expectLater(
      carol.decryptGroup(_group, asha.address, after),
      throwsA(anything),
    );
  });
}
