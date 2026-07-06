import 'dart:async';
import 'dart:convert';

import 'package:fieldchat/features/sync/message_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The production relay. Envelopes are rows in the `envelopes` table; the
/// server assigns `seq`, Realtime fans out inserts, and `fetchSince` catches
/// up. Only ciphertext is stored, base64-encoded.
class SupabaseTransport implements MessageTransport {
  SupabaseTransport(this._client);

  final SupabaseClient _client;
  static const _table = 'envelopes';

  @override
  Future<int> publish(Envelope envelope) async {
    final row = await _client
        .from(_table)
        .upsert({
          'group_id': envelope.groupId,
          'message_id': envelope.messageId,
          'sender_id': envelope.senderId,
          'ciphertext': base64Encode(envelope.ciphertext),
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
    final rows = await _client
        .from(_table)
        .select()
        .eq('group_id', groupId)
        .gt('seq', afterSeq)
        .order('seq');
    return [for (final row in rows) _envelopeFrom(row)];
  }

  Envelope _envelopeFrom(Map<String, dynamic> row) => Envelope(
    groupId: row['group_id'] as String,
    messageId: row['message_id'] as String,
    senderId: row['sender_id'] as String,
    ciphertext: base64Decode(row['ciphertext'] as String),
    seq: (row['seq'] as num).toInt(),
  );
}
