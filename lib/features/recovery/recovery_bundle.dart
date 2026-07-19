import 'dart:convert';

/// A group's key material, enough to re-attach it on a restored device.
class BackedUpGroup {
  const BackedUpGroup({
    required this.id,
    required this.encKey,
    required this.role,
  });

  factory BackedUpGroup.fromJson(Map<String, dynamic> json) => BackedUpGroup(
    id: json['id'] as String,
    encKey: json['encKey'] as String,
    role: json['role'] as String,
  );

  final String id;
  final String encKey;
  final String role;

  Map<String, dynamic> toJson() => {'id': id, 'encKey': encKey, 'role': role};
}

/// Everything needed to restore an account: the identity seeds, the device
/// sender id and username, and each group's key. It only ever leaves the device
/// envelope-encrypted, so the server never sees these values in the clear.
class RecoveryBundle {
  const RecoveryBundle({
    required this.signingSeed,
    required this.agreementSeed,
    required this.senderId,
    required this.username,
    required this.groups,
  });

  factory RecoveryBundle.fromJson(Map<String, dynamic> json) => RecoveryBundle(
    signingSeed: json['signingSeed'] as String,
    agreementSeed: json['agreementSeed'] as String,
    senderId: json['senderId'] as String,
    username: json['username'] as String,
    groups: [
      for (final group in (json['groups'] as List).cast<Map<String, dynamic>>())
        BackedUpGroup.fromJson(group),
    ],
  );

  factory RecoveryBundle.fromBytes(List<int> bytes) => RecoveryBundle.fromJson(
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
  );

  final String signingSeed;
  final String agreementSeed;
  final String senderId;
  final String username;
  final List<BackedUpGroup> groups;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'signingSeed': signingSeed,
    'agreementSeed': agreementSeed,
    'senderId': senderId,
    'username': username,
    'groups': [for (final group in groups) group.toJson()],
  };

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));
}
