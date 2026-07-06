import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// A pairwise ciphertext plus whether it opens a session (a prekey message).
typedef PairwiseMessage = ({Uint8List bytes, bool isPreKey});

/// One member's Signal Protocol state and group operations.
///
/// Group messages use sender keys (a ratcheting chain key + a per-sender
/// signing key), giving forward secrecy and per-sender authentication. Each
/// sender key is delivered to members over pairwise X3DH sessions, so the
/// server never sees it. Removing a member is handled by rotating sender keys
/// and redistributing only to those who remain.
///
/// Stores are in memory here; production backs them with secure device
/// storage behind the same class.
class SignalMember {
  SignalMember(this.userId, {this.deviceId = 1})
    : _identityKeyPair = generateIdentityKeyPair(),
      _registrationId = generateRegistrationId(false) {
    _store = InMemorySignalProtocolStore(_identityKeyPair, _registrationId);
    _senderKeyStore = InMemorySenderKeyStore();
  }

  final String userId;
  final int deviceId;
  final IdentityKeyPair _identityKeyPair;
  final int _registrationId;
  late final InMemorySignalProtocolStore _store;
  late final InMemorySenderKeyStore _senderKeyStore;
  int _nextPreKeyId = 1;

  SignalProtocolAddress get address => SignalProtocolAddress(userId, deviceId);

  /// A one-time prekey bundle (public parts only) others use to open a
  /// pairwise session with this member.
  Future<PreKeyBundle> publishBundle() async {
    final preKey = generatePreKeys(_nextPreKeyId, 1).first;
    final signedPreKey = generateSignedPreKey(_identityKeyPair, _nextPreKeyId);
    _nextPreKeyId += 1;
    await _store.storePreKey(preKey.id, preKey);
    await _store.storeSignedPreKey(signedPreKey.id, signedPreKey);
    return PreKeyBundle(
      _registrationId,
      deviceId,
      preKey.id,
      preKey.getKeyPair().publicKey,
      signedPreKey.id,
      signedPreKey.getKeyPair().publicKey,
      signedPreKey.signature,
      _identityKeyPair.getPublicKey(),
    );
  }

  /// Opens a pairwise session to [remote] from their published [bundle].
  Future<void> startSession(
    SignalProtocolAddress remote,
    PreKeyBundle bundle,
  ) async {
    await SessionBuilder.fromSignalStore(
      _store,
      remote,
    ).processPreKeyBundle(bundle);
  }

  Future<PairwiseMessage> encryptPairwise(
    SignalProtocolAddress remote,
    Uint8List plaintext,
  ) async {
    final message = await SessionCipher.fromStore(
      _store,
      remote,
    ).encrypt(plaintext);
    return (
      bytes: message.serialize(),
      isPreKey: message.getType() == CiphertextMessage.prekeyType,
    );
  }

  Future<Uint8List> decryptPairwise(
    SignalProtocolAddress remote,
    PairwiseMessage message,
  ) async {
    final cipher = SessionCipher.fromStore(_store, remote);
    if (message.isPreKey) {
      return cipher.decrypt(PreKeySignalMessage(message.bytes));
    }
    return cipher.decryptFromSignal(
      SignalMessage.fromSerialized(message.bytes),
    );
  }

  /// Creates (or rotates to) this member's sender key for [groupId] and
  /// returns the distribution message to send to each member over pairwise
  /// sessions.
  Future<Uint8List> createSenderKey(String groupId) async {
    final distribution = await GroupSessionBuilder(
      _senderKeyStore,
    ).create(SenderKeyName(groupId, address));
    return distribution.serialize();
  }

  /// Processes a sender-key distribution from [sender] for [groupId].
  Future<void> processSenderKey(
    String groupId,
    SignalProtocolAddress sender,
    Uint8List distribution,
  ) async {
    await GroupSessionBuilder(_senderKeyStore).process(
      SenderKeyName(groupId, sender),
      SenderKeyDistributionMessageWrapper.fromSerialized(distribution),
    );
  }

  Future<Uint8List> encryptGroup(String groupId, Uint8List plaintext) =>
      GroupCipher(
        _senderKeyStore,
        SenderKeyName(groupId, address),
      ).encrypt(plaintext);

  Future<Uint8List> decryptGroup(
    String groupId,
    SignalProtocolAddress sender,
    Uint8List ciphertext,
  ) => GroupCipher(
    _senderKeyStore,
    SenderKeyName(groupId, sender),
  ).decrypt(ciphertext);

  /// Clears this member's sender key for [groupId] so the next
  /// [createSenderKey] generates a fresh one. Used when a member is removed:
  /// the new key is redistributed only to remaining members, locking the
  /// removed member out of future messages.
  Future<void> rotateSenderKey(String groupId) async {
    await _senderKeyStore.storeSenderKey(
      SenderKeyName(groupId, address),
      SenderKeyRecord(),
    );
  }
}
