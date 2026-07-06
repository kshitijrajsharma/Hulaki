/// What a message can carry. The trailing kinds are control messages, not
/// chat: identity announces a member's public keys, and the admin pair drives
/// the signed promotion handshake.
enum MessageKind {
  text,
  photo,
  voice,
  video,
  groupMeta,
  identityAnnounce,
  adminInvite,
  adminAccept,
}

/// The decrypted contents of one message. This is the plaintext that gets
/// encrypted into a transport envelope; the server never sees it.
class MessagePayload {
  const MessagePayload({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.kind,
    required this.createdAtMs,
    this.senderName,
    this.anonymous = false,
    this.body,
    this.tagId,
    this.lat,
    this.lng,
    this.accuracyM,
    this.altitudeM,
    this.headingDeg,
    this.locationPending = false,
    this.mediaId,
    this.mediaMime,
    this.mediaKeyB64,
    this.mediaSha,
    this.replyToId,
    this.editedAtMs,
    this.deletedAtMs,
  });

  factory MessagePayload.fromJson(Map<String, dynamic> json) => MessagePayload(
    id: json['id'] as String,
    groupId: json['groupId'] as String,
    senderId: json['senderId'] as String,
    kind: MessageKind.values.byName(json['kind'] as String),
    createdAtMs: json['createdAtMs'] as int,
    senderName: json['senderName'] as String?,
    anonymous: json['anonymous'] as bool? ?? false,
    body: json['body'] as String?,
    tagId: json['tagId'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    accuracyM: (json['accuracyM'] as num?)?.toDouble(),
    altitudeM: (json['altitudeM'] as num?)?.toDouble(),
    headingDeg: (json['headingDeg'] as num?)?.toDouble(),
    locationPending: json['locationPending'] as bool? ?? false,
    mediaId: json['mediaId'] as String?,
    mediaMime: json['mediaMime'] as String?,
    mediaKeyB64: json['mediaKeyB64'] as String?,
    mediaSha: json['mediaSha'] as String?,
    replyToId: json['replyToId'] as String?,
    editedAtMs: json['editedAtMs'] as int?,
    deletedAtMs: json['deletedAtMs'] as int?,
  );

  final String id;
  final String groupId;
  final String senderId;
  final MessageKind kind;
  final int createdAtMs;
  final String? senderName;
  final bool anonymous;
  final String? body;
  final String? tagId;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final double? altitudeM;
  final double? headingDeg;
  final bool locationPending;
  final String? mediaId;
  final String? mediaMime;
  final String? mediaKeyB64;
  final String? mediaSha;
  final String? replyToId;
  final int? editedAtMs;
  final int? deletedAtMs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'senderId': senderId,
    'kind': kind.name,
    'createdAtMs': createdAtMs,
    if (senderName != null) 'senderName': senderName,
    if (anonymous) 'anonymous': true,
    if (body != null) 'body': body,
    if (tagId != null) 'tagId': tagId,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (accuracyM != null) 'accuracyM': accuracyM,
    if (altitudeM != null) 'altitudeM': altitudeM,
    if (headingDeg != null) 'headingDeg': headingDeg,
    'locationPending': locationPending,
    if (mediaId != null) 'mediaId': mediaId,
    if (mediaMime != null) 'mediaMime': mediaMime,
    if (mediaKeyB64 != null) 'mediaKeyB64': mediaKeyB64,
    if (mediaSha != null) 'mediaSha': mediaSha,
    if (replyToId != null) 'replyToId': replyToId,
    if (editedAtMs != null) 'editedAtMs': editedAtMs,
    if (deletedAtMs != null) 'deletedAtMs': deletedAtMs,
  };
}
