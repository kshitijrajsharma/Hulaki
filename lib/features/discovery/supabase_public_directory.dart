import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:hulaki/features/discovery/public_directory.dart';
import 'package:hulaki/features/identity/guard_request.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The production public directory. Proximity search uses a bounding box on the
/// indexed lat/lng columns, then refines by true distance. Writes an admin
/// makes (publishing or removing a listing) go through the group-guard Edge
/// Function, which verifies the admin signature; reads stay direct.
class SupabasePublicDirectory implements PublicDirectory {
  SupabasePublicDirectory(this._client, this._identity);

  final SupabaseClient _client;

  /// This device's identity, used to sign admin listing writes for the guard.
  final Future<IdentityKeys> Function() _identity;
  static const _table = 'public_groups';
  static const _requestsTable = 'join_requests';
  static const _function = 'group-guard';

  Future<void> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(_function, body: body);
    if (response.status != 200) {
      throw StateError(
        '${body['action']} rejected (${response.status}): ${response.data}',
      );
    }
  }

  @override
  Future<void> publish(PublicGroup group) async {
    final listing = jsonEncode({
      'group_id': group.groupId,
      'name': group.name,
      'description': group.description,
      'scope': group.scope,
      'center_lat': group.centerLat,
      'center_lng': group.centerLng,
      'enc_key': group.encKey,
      'photo': group.photo == null ? null : base64Encode(group.photo!),
      'tags': group.tags.map((t) => t.toJson()).toList(),
      'aoi': group.aoiGeoJson,
      'join_approval': group.joinApproval,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _invoke(
      await GuardRequest.editListing(
        identity: await _identity(),
        groupId: group.groupId,
        ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        listing: listing,
      ),
    );
  }

  @override
  Future<void> requestJoin(JoinRequest request) async {
    await _client.from(_requestsTable).upsert({
      'id': request.id,
      'group_id': request.groupId,
      'requester_id': request.requesterId,
      'requester_name': request.requesterName,
      'signing_key': request.signingKey,
      'agreement_key': request.agreementKey,
    }, onConflict: 'group_id,requester_id');
  }

  @override
  Future<List<JoinRequest>> pendingRequests(String groupId) async {
    final rows = await _client
        .from(_requestsTable)
        .select()
        .eq('group_id', groupId)
        .isFilter('sealed_key', null);
    return [for (final row in rows) _requestFromRow(row)];
  }

  @override
  Future<JoinRequest?> myRequest(String groupId, String requesterId) async {
    final row = await _client
        .from(_requestsTable)
        .select()
        .eq('group_id', groupId)
        .eq('requester_id', requesterId)
        .maybeSingle();
    return row == null ? null : _requestFromRow(row);
  }

  @override
  Future<void> approveRequest(String requestId, String sealedKey) async {
    await _client
        .from(_requestsTable)
        .update({'sealed_key': sealedKey})
        .eq('id', requestId);
  }

  @override
  Future<void> declineRequest(String requestId) async {
    await _client.from(_requestsTable).delete().eq('id', requestId);
  }

  JoinRequest _requestFromRow(Map<String, dynamic> row) => JoinRequest(
    id: row['id'] as String,
    groupId: row['group_id'] as String,
    requesterId: row['requester_id'] as String,
    requesterName: row['requester_name'] as String?,
    signingKey: row['signing_key'] as String,
    agreementKey: row['agreement_key'] as String,
    sealedKey: row['sealed_key'] as String?,
  );

  @override
  Future<void> remove(String groupId) async {
    await _invoke(
      await GuardRequest.deleteListing(
        identity: await _identity(),
        groupId: groupId,
        ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }

  @override
  Future<List<PublicGroup>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 25,
  }) async {
    final deltaLat = radiusKm / 111.0;
    final deltaLng = radiusKm / (111.0 * math.cos(lat * math.pi / 180));
    final rows = await _client
        .from(_table)
        .select()
        .eq('scope', 'local')
        .gte('center_lat', lat - deltaLat)
        .lte('center_lat', lat + deltaLat)
        .gte('center_lng', lng - deltaLng)
        .lte('center_lng', lng + deltaLng);

    final radiusM = radiusKm * 1000;
    final results = <PublicGroup>[];
    for (final row in rows) {
      final centerLat = (row['center_lat'] as num).toDouble();
      final centerLng = (row['center_lng'] as num).toDouble();
      final meters = Geolocator.distanceBetween(
        lat,
        lng,
        centerLat,
        centerLng,
      );
      if (meters > radiusM) continue;
      results.add(_groupFromRow(row, distanceM: meters));
    }
    results.sort((a, b) => a.distanceM!.compareTo(b.distanceM!));
    return results;
  }

  @override
  Future<List<PublicGroup>> globalFeed({int limit = 50, int offset = 0}) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('scope', 'global')
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final row in rows) _groupFromRow(row)];
  }

  @override
  Future<List<PublicGroup>> searchByName(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    // Escape LIKE wildcards so the text matches literally, not as a pattern.
    final escaped = normalized.replaceAllMapped(
      RegExp(r'[%_\\]'),
      (match) => '\\${match[0]}',
    );
    final rows = await _client
        .from(_table)
        .select()
        .ilike('name', '%$escaped%')
        .limit(50);
    return [for (final row in rows) _groupFromRow(row)];
  }

  PublicGroup _groupFromRow(Map<String, dynamic> row, {double? distanceM}) {
    final photo = row['photo'] as String?;
    final tags = row['tags'] as List<dynamic>?;
    return PublicGroup(
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      scope: row['scope'] as String? ?? 'local',
      description: row['description'] as String?,
      centerLat: (row['center_lat'] as num?)?.toDouble(),
      centerLng: (row['center_lng'] as num?)?.toDouble(),
      encKey: row['enc_key'] as String,
      photo: photo == null ? null : base64Decode(photo),
      tags: tags == null
          ? const []
          : [
              for (final tag in tags)
                DirectoryTag.fromJson(tag as Map<String, dynamic>),
            ],
      aoiGeoJson: row['aoi'] as String?,
      joinApproval: row['join_approval'] as bool? ?? false,
      distanceM: distanceM,
    );
  }
}
