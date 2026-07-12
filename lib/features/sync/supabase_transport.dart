import 'dart:async';
import 'dart:convert';

import 'package:hulaki/features/identity/guard_request.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';
import 'package:hulaki/features/sync/message_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The production relay. Envelopes are rows in the `envelopes` table; the
/// server assigns `seq`, Realtime fans out inserts, and `fetchSince` catches
/// up. Only ciphertext is stored, base64-encoded.
class SupabaseTransport implements MessageTransport {
  SupabaseTransport(this._client, this._identity);

  final SupabaseClient _client;

  /// This device's identity, used to sign an admin's group purge for the guard.
  final Future<IdentityKeys> Function() _identity;
  static const _table = 'envelopes';
  static const _function = 'group-guard';

  @override
  Future<int> publish(Envelope envelope) async {
    final row = await _client
        .from(_table)
        .upsert({
          'group_id': envelope.groupId,
          'message_id': envelope.messageId,
          'sender_id': envelope.senderId,
          'ciphertext': base64Encode(envelope.ciphertext),
          'sender_pubkey': envelope.senderPubkey,
        }, onConflict: 'group_id,message_id')
        .select('seq')
        .single();
    return (row['seq'] as num).toInt();
  }

  @override
  Stream<Envelope> subscribe(String groupId) {
    final controller = StreamController<Envelope>.broadcast();
    final channel = _client.channel('envelopes:$groupId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (payload) =>
              controller.add(_envelopeFrom(payload.newRecord)),
        )
        .subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Future<List<Envelope>> fetchSince(String groupId, int afterSeq) async {
    // Page by seq so a group with more envelopes than the server's default row
    // cap still catches up fully, instead of silently stopping at one page.
    const pageSize = 1000;
    final envelopes = <Envelope>[];
    var cursor = afterSeq;
    while (true) {
      final rows = await _client
          .from(_table)
          .select()
          .eq('group_id', groupId)
          .gt('seq', cursor)
          // Ascending, so metas replay oldest-first and the newest edit wins.
          // supabase-dart's order() defaults to descending, which would let the
          // create-time meta clobber later tag and area edits.
          .order('seq', ascending: true)
          .limit(pageSize);
      if (rows.isEmpty) break;
      for (final row in rows) {
        envelopes.add(_envelopeFrom(row));
      }
      cursor = envelopes.last.seq;
      if (rows.length < pageSize) break;
    }
    return envelopes;
  }

  @override
  Future<void> purgeGroup(String groupId) async {
    final identity = await _identity();
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final response = await _client.functions.invoke(
      _function,
      body: await GuardRequest.purgeGroup(
        identity: identity,
        groupId: groupId,
        ts: ts,
      ),
    );
    if (response.status != 200) {
      throw StateError(
        'purge-group rejected (${response.status}): ${response.data}',
      );
    }
  }

  Envelope _envelopeFrom(Map<String, dynamic> row) => Envelope(
    groupId: row['group_id'] as String,
    messageId: row['message_id'] as String,
    senderId: row['sender_id'] as String,
    ciphertext: base64Decode(row['ciphertext'] as String),
    seq: (row['seq'] as num).toInt(),
  );
}
