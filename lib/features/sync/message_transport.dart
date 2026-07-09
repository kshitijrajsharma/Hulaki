import 'dart:typed_data';

/// One encrypted message as the server sees it: routing metadata plus an
/// opaque ciphertext. [seq] is assigned by the server and orders the group.
class Envelope {
  const Envelope({
    required this.groupId,
    required this.messageId,
    required this.senderId,
    required this.ciphertext,
    this.seq = 0,
  });

  final String groupId;
  final String messageId;
  final String senderId;
  final Uint8List ciphertext;
  final int seq;

  Envelope withSeq(int value) => Envelope(
    groupId: groupId,
    messageId: messageId,
    senderId: senderId,
    ciphertext: ciphertext,
    seq: value,
  );
}

/// The relay: stores encrypted envelopes and fans them out live. Backed by an
/// in-memory implementation for tests and local development, and by Supabase
/// (Realtime + Postgres) in production behind the same contract.
abstract interface class MessageTransport {
  /// Publishes [envelope] and returns the sequence the server assigned.
  Future<int> publish(Envelope envelope);

  /// Live envelopes for a group as they are published.
  Stream<Envelope> subscribe(String groupId);

  /// Envelopes with a sequence greater than [afterSeq], for catch-up.
  Future<List<Envelope>> fetchSince(String groupId, int afterSeq);

  /// Deletes every stored envelope for a group, for an admin's delete. Leaving
  /// a group never calls this, so other members keep the data.
  Future<void> purgeGroup(String groupId);
}
