import 'dart:typed_data';

import 'package:fieldchat/features/groups/invite_link.dart';
import 'package:geolocator/geolocator.dart';

/// One of a group's quick tags as shown in its public preview.
class DirectoryTag {
  const DirectoryTag({
    required this.label,
    required this.colorValue,
    this.iconName,
  });

  factory DirectoryTag.fromJson(Map<String, dynamic> json) => DirectoryTag(
    label: json['label'] as String,
    colorValue: (json['colorValue'] as num).toInt(),
    iconName: json['iconName'] as String?,
  );

  final String label;
  final int colorValue;
  final String? iconName;

  Map<String, dynamic> toJson() => {
    'label': label,
    'colorValue': colorValue,
    if (iconName != null) 'iconName': iconName,
  };
}

/// A discoverable public group as it appears in the nearby directory. Carries
/// the group key, so a public group is joinable by anyone who finds it, plus
/// the preview shown before joining (photo, tags, mappers, area).
class PublicGroup {
  const PublicGroup({
    required this.groupId,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.encKey,
    this.description,
    this.photo,
    this.tags = const [],
    this.mapperCount = 0,
    this.aoiGeoJson,
    this.joinApproval = false,
    this.distanceM,
  });

  final String groupId;
  final String name;
  final String? description;
  final double centerLat;
  final double centerLng;
  final String encKey;
  final Uint8List? photo;
  final List<DirectoryTag> tags;
  final int mapperCount;
  final String? aoiGeoJson;

  /// When true the key is withheld from the listing; joining needs an admin's
  /// approval, delivered as a sealed key through [PublicDirectory.requestJoin].
  final bool joinApproval;

  /// Distance from the searcher, filled by [PublicDirectory.nearby].
  final double? distanceM;

  String get inviteUrl => InviteLink(groupId: groupId, key: encKey).url;

  PublicGroup withDistance(double meters) => PublicGroup(
    groupId: groupId,
    name: name,
    centerLat: centerLat,
    centerLng: centerLng,
    encKey: encKey,
    description: description,
    photo: photo,
    tags: tags,
    mapperCount: mapperCount,
    aoiGeoJson: aoiGeoJson,
    joinApproval: joinApproval,
    distanceM: meters,
  );
}

/// A request to join an approval-gated group, carrying the requester's public
/// keys so an admin can seal the group key back to them.
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.requesterId,
    required this.signingKey,
    required this.agreementKey,
    this.requesterName,
    this.sealedKey,
  });

  final String id;
  final String groupId;
  final String requesterId;
  final String? requesterName;

  /// The requester's base64 Ed25519 and X25519 public keys.
  final String signingKey;
  final String agreementKey;

  /// The group key sealed to [agreementKey], written by an admin on approval.
  final String? sealedKey;
}

/// The public directory of discoverable groups. Backed by Supabase in
/// production and an in-memory map in tests.
abstract interface class PublicDirectory {
  /// Lists or updates the group in the directory.
  Future<void> publish(PublicGroup group);

  /// Removes the group from the directory (made private or deleted).
  Future<void> remove(String groupId);

  /// Groups within [radiusKm] of the given point, nearest first.
  Future<List<PublicGroup>> nearby({
    required double lat,
    required double lng,
    double radiusKm,
  });

  /// Groups whose name contains [query] (case-insensitive), for finding a group
  /// by name beyond the nearby radius. Empty when [query] is blank.
  Future<List<PublicGroup>> searchByName(String query);

  /// Files a request to join an approval-gated group.
  Future<void> requestJoin(JoinRequest request);

  /// The pending requests for a group, for an admin to review.
  Future<List<JoinRequest>> pendingRequests(String groupId);

  /// This device's own request for a group, so the requester can poll for the
  /// sealed key once an admin approves. Null when no request exists.
  Future<JoinRequest?> myRequest(String groupId, String requesterId);

  /// Approves a request by writing back the group key sealed to the requester.
  Future<void> approveRequest(String requestId, String sealedKey);

  /// Declines a request, removing it.
  Future<void> declineRequest(String requestId);
}

/// A single-process directory for tests and local development.
class InMemoryPublicDirectory implements PublicDirectory {
  final Map<String, PublicGroup> _entries = {};
  final Map<String, JoinRequest> _requests = {};

  @override
  Future<void> publish(PublicGroup group) async {
    _entries[group.groupId] = group;
  }

  @override
  Future<void> remove(String groupId) async {
    _entries.remove(groupId);
    _requests.removeWhere((_, request) => request.groupId == groupId);
  }

  @override
  Future<void> requestJoin(JoinRequest request) async {
    _requests[request.id] = request;
  }

  @override
  Future<List<JoinRequest>> pendingRequests(String groupId) async => [
    for (final request in _requests.values)
      if (request.groupId == groupId && request.sealedKey == null) request,
  ];

  @override
  Future<JoinRequest?> myRequest(String groupId, String requesterId) async {
    for (final request in _requests.values) {
      if (request.groupId == groupId && request.requesterId == requesterId) {
        return request;
      }
    }
    return null;
  }

  @override
  Future<void> approveRequest(String requestId, String sealedKey) async {
    final request = _requests[requestId];
    if (request == null) return;
    _requests[requestId] = JoinRequest(
      id: request.id,
      groupId: request.groupId,
      requesterId: request.requesterId,
      requesterName: request.requesterName,
      signingKey: request.signingKey,
      agreementKey: request.agreementKey,
      sealedKey: sealedKey,
    );
  }

  @override
  Future<void> declineRequest(String requestId) async {
    _requests.remove(requestId);
  }

  @override
  Future<List<PublicGroup>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 25,
  }) async {
    final radiusM = radiusKm * 1000;
    final withDistance = <PublicGroup>[];
    for (final group in _entries.values) {
      final meters = Geolocator.distanceBetween(
        lat,
        lng,
        group.centerLat,
        group.centerLng,
      );
      if (meters <= radiusM) withDistance.add(group.withDistance(meters));
    }
    withDistance.sort((a, b) => a.distanceM!.compareTo(b.distanceM!));
    return withDistance;
  }

  @override
  Future<List<PublicGroup>> searchByName(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    return [
      for (final group in _entries.values)
        if (group.name.toLowerCase().contains(normalized)) group,
    ]..sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }
}
