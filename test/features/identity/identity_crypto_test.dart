import 'dart:convert';
import 'dart:typed_data';

import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a signature verifies against the signer public key', () async {
    final keys = await IdentityKeys.generate();
    final message = utf8.encode('promote:alice');

    final signature = await keys.sign(message);

    expect(
      await IdentityKeys.verify(
        message,
        signature: signature,
        signerPublic: keys.signingPublic,
      ),
      isTrue,
    );
  });

  test('verification fails for a tampered message', () async {
    final keys = await IdentityKeys.generate();
    final signature = await keys.sign(utf8.encode('promote:alice'));

    expect(
      await IdentityKeys.verify(
        utf8.encode('promote:mallory'),
        signature: signature,
        signerPublic: keys.signingPublic,
      ),
      isFalse,
    );
  });

  test('verification fails against a different signer', () async {
    final signer = await IdentityKeys.generate();
    final other = await IdentityKeys.generate();
    final message = utf8.encode('approve:bob');
    final signature = await signer.sign(message);

    expect(
      await IdentityKeys.verify(
        message,
        signature: signature,
        signerPublic: other.signingPublic,
      ),
      isFalse,
    );
  });

  test(
    'a sealed group key opens only with the recipient private key',
    () async {
      final recipient = await IdentityKeys.generate();
      final groupKey = Uint8List.fromList(List<int>.generate(32, (i) => i));

      final sealed = await IdentityKeys.seal(
        groupKey,
        recipientAgreementPublic: recipient.agreementPublic,
      );
      final opened = await recipient.open(sealed);

      expect(opened, groupKey);
    },
  );

  test('a sealed box does not open with a different identity', () async {
    final recipient = await IdentityKeys.generate();
    final intruder = await IdentityKeys.generate();
    final sealed = await IdentityKeys.seal(
      Uint8List.fromList([1, 2, 3, 4]),
      recipientAgreementPublic: recipient.agreementPublic,
    );

    await expectLater(intruder.open(sealed), throwsA(isA<Object>()));
  });

  test('identity restored from seeds keeps the same public keys', () async {
    final keys = await IdentityKeys.generate();

    final restored = await IdentityKeys.fromSeeds(
      signingSeed: await keys.signingSeed(),
      agreementSeed: await keys.agreementSeed(),
    );

    expect(restored.signingPublic, keys.signingPublic);
    expect(restored.agreementPublic, keys.agreementPublic);
  });
}
