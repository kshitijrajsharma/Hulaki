import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/message_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps the in-memory relay and fails every publish while [down], to stand in
/// for a dropped network.
class _FlakyTransport implements MessageTransport {
  _FlakyTransport(this._inner);

  final InMemoryTransport _inner;
  bool down = false;

  @override
  Future<int> publish(Envelope envelope) {
    if (down) throw Exception('transport down');
    return _inner.publish(envelope);
  }

  @override
  Stream<Envelope> subscribe(String groupId) => _inner.subscribe(groupId);

  @override
  Future<List<Envelope>> fetchSince(String groupId, int afterSeq) =>
      _inner.fetchSince(groupId, afterSeq);

  @override
  Future<void> purgeGroup(String groupId) => _inner.purgeGroup(groupId);
}

Future<void> _waitFor(
  Future<bool> Function() condition, {
  int tries = 400,
}) async {
  for (var i = 0; i < tries; i++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not met in time');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a send that fails while the transport is down is retried', () async {
    final inner = InMemoryTransport();
    final flaky = _FlakyTransport(inner);
    final db = LocalDatabase(NativeDatabase.memory());
    final identity = await IdentityKeys.generate();
    final sync = SyncService(
      db: db,
      transport: flaky,
      blobStore: InMemoryBlobStore(),
      currentUserId: 'owner',
      identity: () async => identity,
      minRetry: const Duration(milliseconds: 20),
    );
    final groups = GroupService(db: db, sync: sync, currentUserId: 'owner');
    addTearDown(() async {
      await sync.dispose();
      await db.close();
      await inner.dispose();
    });

    final group = await groups.createGroup(
      name: 'Ward survey',
      identity: identity,
      hotKeys: const [],
    );

    // The network drops before the send: it is captured locally but cannot
    // publish, so it stays pending with nothing on the relay.
    flaky.down = true;
    final messageId = await sync.sendText(groupId: group.id, text: 'stuck');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final rows = await db.messagesFor(group.id);
    expect(rows.firstWhere((m) => m.id == messageId).sendState, 'pending');

    // The network recovers; the backoff retry publishes it with no further
    // action from the caller.
    flaky.down = false;
    await _waitFor(() async {
      final current = await db.messagesFor(group.id);
      return current.firstWhere((m) => m.id == messageId).sendState == 'sent';
    });
    expect(await inner.fetchSince(group.id, 0), isNotEmpty);
  });
}
