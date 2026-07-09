import 'dart:async';

import 'package:fieldchat/features/sync/message_transport.dart';

/// A single-process stand-in for the server relay. Holds encrypted envelopes
/// per group, assigns sequences, and broadcasts to live subscribers. Lets
/// several simulated clients in one test talk to each other.
class InMemoryTransport implements MessageTransport {
  final Map<String, List<Envelope>> _log = {};
  final Map<String, StreamController<Envelope>> _streams = {};
  int _seq = 0;

  @override
  Future<int> publish(Envelope envelope) async {
    final seq = ++_seq;
    final stored = envelope.withSeq(seq);
    _log.putIfAbsent(envelope.groupId, () => []).add(stored);
    _streams[envelope.groupId]?.add(stored);
    return seq;
  }

  @override
  Stream<Envelope> subscribe(String groupId) {
    final controller = _streams.putIfAbsent(
      groupId,
      StreamController<Envelope>.broadcast,
    );
    return controller.stream;
  }

  @override
  Future<List<Envelope>> fetchSince(String groupId, int afterSeq) async {
    final log = _log[groupId] ?? const [];
    return log.where((e) => e.seq > afterSeq).toList();
  }

  @override
  Future<void> purgeGroup(String groupId) async {
    _log.remove(groupId);
  }

  Future<void> dispose() async {
    for (final controller in _streams.values) {
      await controller.close();
    }
  }
}
