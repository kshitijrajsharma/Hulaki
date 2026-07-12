import 'dart:convert';
import 'dart:typed_data';

import 'package:hulaki/features/identity/identity_crypto.dart';

/// Raised when an admin statement fails verification or violates the trust
/// rules (a non-self-signed root, or an addition not signed by a known admin).
class AdminRegistryException implements Exception {
  const AdminRegistryException(this.message);
  final String message;
  @override
  String toString() => 'AdminRegistryException: $message';
}

/// A signed claim that [adminPubkey] is an admin of [groupId], authorised by
/// the holder of [addedBy]. The creator seeds the group by self-signing (so
/// addedBy equals adminPubkey); every later admin is authorised by an existing
/// admin. It carries only public keys, so it is safe to store on the server.
class AdminStatement {
  const AdminStatement({
    required this.groupId,
    required this.adminPubkey,
    required this.addedBy,
    required this.sig,
  });

  factory AdminStatement.fromJson(Map<String, dynamic> json) => AdminStatement(
    groupId: json['group_id'] as String,
    adminPubkey: json['admin_pubkey'] as String,
    addedBy: json['added_by'] as String,
    sig: json['sig'] as String,
  );

  final String groupId;

  /// Base64 Ed25519 public key being granted admin.
  final String adminPubkey;

  /// Base64 Ed25519 public key that signed this statement.
  final String addedBy;

  /// Base64 signature over [signedBytes].
  final String sig;

  /// A root seeds a group and must be self-signed by the creator.
  bool get isRoot => addedBy == adminPubkey;

  /// The exact bytes the author signs. Binding the group id stops a statement
  /// being replayed into another group; binding the granted key stops it being
  /// swapped for a different one.
  List<int> signedBytes() => utf8.encode('$groupId|$adminPubkey');

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'admin_pubkey': adminPubkey,
    'added_by': addedBy,
    'sig': sig,
  };
}

/// Signs a statement granting [adminPublic] admin of [groupId], authored by
/// [signer]. For the root, [adminPublic] is the creator's own signing key.
Future<AdminStatement> signAdminStatement({
  required IdentityKeys signer,
  required String groupId,
  required Uint8List adminPublic,
}) async {
  final adminB64 = base64Encode(adminPublic);
  final signature = await signer.sign(utf8.encode('$groupId|$adminB64'));
  return AdminStatement(
    groupId: groupId,
    adminPubkey: adminB64,
    addedBy: base64Encode(signer.signingPublic),
    sig: base64Encode(signature),
  );
}

/// The server-readable admin set. The production implementation posts to the
/// group-guard Edge Function, which enforces the same rules as
/// [InMemoryAdminRegistry] before writing with the service role.
abstract interface class AdminRegistry {
  /// Publishes a statement, or throws [AdminRegistryException] if it is
  /// rejected. Accepting the same admin twice is a no-op.
  Future<void> submit(AdminStatement statement);

  /// The base64 admin public keys currently recorded for [groupId].
  Future<Set<String>> adminsFor(String groupId);
}

/// An in-process registry that enforces the trust model: a group is seeded by
/// exactly one self-signed root, and every later admin must be authorised by a
/// key that is already an admin. Used by tests and keyless local runs.
class InMemoryAdminRegistry implements AdminRegistry {
  final Map<String, Map<String, AdminStatement>> _byGroup = {};

  @override
  Future<void> submit(AdminStatement statement) async {
    final verified = await IdentityKeys.verify(
      statement.signedBytes(),
      signature: base64Decode(statement.sig),
      signerPublic: base64Decode(statement.addedBy),
    );
    if (!verified) {
      throw const AdminRegistryException('signature does not verify');
    }
    final admins = _byGroup[statement.groupId];
    if (admins == null || admins.isEmpty) {
      if (!statement.isRoot) {
        throw const AdminRegistryException(
          'first admin of a group must be a self-signed root',
        );
      }
      _byGroup[statement.groupId] = {statement.adminPubkey: statement};
      return;
    }
    if (!admins.containsKey(statement.addedBy)) {
      throw const AdminRegistryException(
        'author is not an admin of this group',
      );
    }
    admins[statement.adminPubkey] = statement;
  }

  @override
  Future<Set<String>> adminsFor(String groupId) async =>
      _byGroup[groupId]?.keys.toSet() ?? <String>{};
}
