import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/groups/invite_link.dart';
import 'package:hulaki/features/identity/admin_chain.dart';
import 'package:hulaki/features/identity/admin_registry.dart';
import 'package:hulaki/features/identity/admin_roles.dart';
import 'package:hulaki/features/identity/identity_crypto.dart';
import 'package:hulaki/features/messaging/domain/message_payload.dart';
import 'package:hulaki/features/sync/group_cipher.dart';
import 'package:hulaki/features/sync/sync_service.dart';
import 'package:hulaki/features/zones/domain/zone.dart';
import 'package:uuid/uuid.dart';

/// A tag to create on a new group: its label, ARGB colour, optional icon and
/// optional one-line description of what it is for.
class HotKeySpec {
  const HotKeySpec({
    required this.label,
    required this.colorValue,
    this.iconName,
    this.description,
  });

  final String label;
  final int colorValue;
  final String? iconName;
  final String? description;
}

/// A hot-key being edited. A null [id] is a new one; an existing id is kept so
/// messages already tagged with it stay linked.
class EditableHotKey {
  EditableHotKey({
    required this.label,
    required this.colorValue,
    this.iconName,
    this.description,
    this.id,
  });

  final String? id;
  String label;
  int colorValue;
  String? iconName;
  String? description;
}

/// Creating and joining mapping groups. A new group gets a fresh encryption
/// key; its metadata is published over the encrypted pipeline so members who
/// join by link receive the name, hot-keys and area.
class GroupService {
  GroupService({
    required this.db,
    required this.sync,
    required this.currentUserId,
    this.adminRegistry,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final LocalDatabase db;
  final SyncService sync;
  final String currentUserId;

  /// The server-readable admin set. Null in tests and keyless runs, where no
  /// server enforces deletes, so publishing is skipped.
  final AdminRegistry? adminRegistry;
  final Uuid _uuid;

  Future<Group> createGroup({
    required String name,
    required List<HotKeySpec> hotKeys,
    required IdentityKeys identity,
    String? description,
    String? aoiGeoJson,
    Uint8List? photo,
    bool isPublic = false,
  }) async {
    final id = _uuid.v4();
    final key = base64Encode(await GroupCipher.generateKey());
    final rootKey = base64Encode(identity.signingPublic);
    final agreementKey = base64Encode(identity.agreementPublic);

    String? photoBlobId;
    String? photoKey;
    if (photo != null) {
      photoBlobId = _uuid.v4();
      photoKey = base64Encode(await GroupCipher.generateKey());
      await db
          .into(db.mediaBlobs)
          .insert(
            MediaBlobsCompanion.insert(
              id: photoBlobId,
              bytes: photo,
              mime: 'image/jpeg',
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: id,
            name: name,
            description: Value(description),
            createdBy: currentUserId,
            encKey: key,
            aoiGeoJson: Value(aoiGeoJson),
            isPublic: Value(isPublic),
            // Approval-gated by default, so a public group is discoverable but
            // its key is withheld until an admin approves each joiner.
            joinApproval: const Value(true),
            adminRootKey: Value(rootKey),
            photo: Value(photo),
            photoBlobId: Value(photoBlobId),
            photoKey: Value(photoKey),
          ),
        );
    await _storeSelfIdentity(rootKey, agreementKey);

    final specs = <Map<String, dynamic>>[];
    for (var i = 0; i < hotKeys.length; i++) {
      final hotKeyId = _uuid.v4();
      await db
          .into(db.hotKeys)
          .insert(
            HotKeysCompanion.insert(
              id: hotKeyId,
              groupId: id,
              label: hotKeys[i].label,
              colorValue: hotKeys[i].colorValue,
              iconName: Value(hotKeys[i].iconName),
              description: Value(hotKeys[i].description),
              position: Value(i),
            ),
          );
      specs.add({
        'id': hotKeyId,
        'label': hotKeys[i].label,
        'colorValue': hotKeys[i].colorValue,
        'iconName': hotKeys[i].iconName,
        'description': hotKeys[i].description,
        'position': i,
      });
    }

    await _addMembership(id, role: 'admin');
    // Seed the server-readable admin set with the creator's self-signed root,
    // so the guard can later authorise this admin's deletes and listing edits.
    await adminRegistry?.submit(
      await signAdminStatement(
        signer: identity,
        groupId: id,
        adminPublic: identity.signingPublic,
      ),
    );
    // Announce this device's keys first, so its signing key is the first
    // envelope and is known before any content it authors is verified on other
    // devices. The full meta follows; it still precedes any later tag edit, so
    // an edit cannot be pruned back to the original tags on other devices.
    await announceIdentity(id, identity);
    await _publishFullMeta(id);
    await sync.start(id);

    return (await db.groupById(id))!;
  }

  /// Records this device's own public keys against its profile so its keys are
  /// available locally the same way peers' announced keys are.
  Future<void> _storeSelfIdentity(String signingKey, String agreementKey) =>
      db.upsertProfile(
        ProfilesCompanion.insert(
          id: currentUserId,
          phone: '',
          signingKey: Value(signingKey),
          agreementKey: Value(agreementKey),
        ),
      );

  /// Announces this device's public keys to a group so members can verify its
  /// signatures, promote it, and seal it the group key at approval time.
  Future<void> announceIdentity(String groupId, IdentityKeys identity) async {
    final signingKey = base64Encode(identity.signingPublic);
    final agreementKey = base64Encode(identity.agreementPublic);
    await _storeSelfIdentity(signingKey, agreementKey);
    final self = await db.profileById(currentUserId);
    await sync.publishControl(
      groupId: groupId,
      kind: MessageKind.identityAnnounce,
      body: {
        'username': self?.displayName,
        'signingKey': signingKey,
        'agreementKey': agreementKey,
      },
    );
  }

  /// Replaces a group's hot-keys and republishes its metadata so members see
  /// the change. Existing ids are updated in place; missing ones are removed.
  Future<void> updateHotKeys(
    String groupId,
    List<EditableHotKey> hotKeys,
  ) async {
    final existing = await db.hotKeysFor(groupId);
    final keptIds = <String>{};
    final specs = <Map<String, dynamic>>[];

    for (var i = 0; i < hotKeys.length; i++) {
      final hotKey = hotKeys[i];
      final id = hotKey.id ?? _uuid.v4();
      keptIds.add(id);
      await db
          .into(db.hotKeys)
          .insert(
            HotKeysCompanion.insert(
              id: id,
              groupId: groupId,
              label: hotKey.label,
              colorValue: hotKey.colorValue,
              iconName: Value(hotKey.iconName),
              description: Value(hotKey.description),
              position: Value(i),
            ),
            onConflict: DoUpdate(
              (_) => HotKeysCompanion(
                label: Value(hotKey.label),
                colorValue: Value(hotKey.colorValue),
                iconName: Value(hotKey.iconName),
                description: Value(hotKey.description),
                position: Value(i),
              ),
            ),
          );
      specs.add({
        'id': id,
        'label': hotKey.label,
        'colorValue': hotKey.colorValue,
        'iconName': hotKey.iconName,
        'description': hotKey.description,
        'position': i,
      });
    }

    for (final row in existing) {
      if (!keptIds.contains(row.id)) {
        await (db.delete(db.hotKeys)..where((h) => h.id.equals(row.id))).go();
      }
    }

    await _publishFullMeta(groupId);
  }

  /// Republishes a group's complete metadata from the local state, so members
  /// converge on name, description, area, public flag and hot-keys together.
  Future<void> _publishFullMeta(String groupId) async {
    final group = await db.groupById(groupId);
    if (group == null) return;
    final hotKeys = await db.hotKeysFor(groupId);
    final self = await db.profileById(currentUserId);
    await sync.publishGroupMeta(
      groupId: groupId,
      photoBlobId: group.photoBlobId,
      photoKeyB64: group.photoKey,
      meta: {
        'name': group.name,
        'description': group.description,
        'aoiGeoJson': group.aoiGeoJson,
        'zonesGeoJson': group.zonesGeoJson,
        'isPublic': group.isPublic,
        'joinApproval': group.joinApproval,
        'scope': group.scope,
        'allowMemberExport': group.allowMemberExport,
        'allowMemberPlace': group.allowMemberPlace,
        'allowOutsideArea': group.allowOutsideArea,
        'gpsLimitM': group.gpsLimitM,
        'allowMemberTags': group.allowMemberTags,
        'allowChatMode': group.allowChatMode,
        'requireZone': group.requireZone,
        'adminRootKey': group.adminRootKey,
        'creatorName': self?.displayName,
        'creatorAgreementKey': self?.agreementKey,
        'hotKeys': [
          for (var i = 0; i < hotKeys.length; i++)
            {
              'id': hotKeys[i].id,
              'label': hotKeys[i].label,
              'colorValue': hotKeys[i].colorValue,
              'iconName': hotKeys[i].iconName,
              'description': hotKeys[i].description,
              'position': i,
            },
        ],
      },
    );
  }

  /// Sets or clears the group's cover photo and shares it with members through
  /// the encrypted blob path. A new photo gets a fresh blob id and key, staged
  /// locally so the sync drain uploads it; republishing the metadata carries
  /// the reference. Clearing drops it locally only.
  Future<void> updateGroupPhoto(String groupId, Uint8List? photo) async {
    if (photo == null) {
      await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
        const GroupsCompanion(
          photo: Value(null),
          photoBlobId: Value(null),
          photoKey: Value(null),
        ),
      );
      await _publishFullMeta(groupId);
      return;
    }
    final blobId = _uuid.v4();
    final key = base64Encode(await GroupCipher.generateKey());
    await db
        .into(db.mediaBlobs)
        .insert(
          MediaBlobsCompanion.insert(
            id: blobId,
            bytes: photo,
            mime: 'image/jpeg',
          ),
          mode: InsertMode.insertOrReplace,
        );
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(
        photo: Value(photo),
        photoBlobId: Value(blobId),
        photoKey: Value(key),
      ),
    );
    await _publishFullMeta(groupId);
  }

  /// Renames the group and republishes its metadata so members converge.
  Future<void> renameGroup(String groupId, String name) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(name: Value(name)),
    );
    await _publishFullMeta(groupId);
  }

  /// Updates the group's description and republishes metadata.
  Future<void> setDescription(String groupId, String? description) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(description: Value(description)),
    );
    await _publishFullMeta(groupId);
  }

  /// Sets or clears the group's mapping area and republishes, so members
  /// converge on it and out-of-area enforcement uses the new shape.
  Future<void> setMappingArea(String groupId, String? aoiGeoJson) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(aoiGeoJson: Value(aoiGeoJson)),
    );
    await _publishFullMeta(groupId);
  }

  /// Sets or clears the group's zones and republishes so members converge on
  /// the split. An empty list clears it, leaving the mapping area intact.
  Future<void> setZones(String groupId, List<Zone> zones) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(
        zonesGeoJson: Value(zones.isEmpty ? null : zonesToGeoJson(zones)),
      ),
    );
    await _publishFullMeta(groupId);
  }

  /// Clears the split, dropping every zone but keeping the mapping area.
  Future<void> clearZones(String groupId) => setZones(groupId, const []);

  /// Records the caller's own zone pick and shares it. Null leaves the member
  /// unassigned. Authored only for oneself; peers reject a pick naming another.
  Future<void> assignMyZone(String groupId, String? zoneId) async {
    await sync.publishControl(
      groupId: groupId,
      kind: MessageKind.zoneAssign,
      body: {'profileId': currentUserId, 'zoneId': zoneId},
    );
    await db.setAssignedZone(groupId, currentUserId, zoneId);
  }

  /// Sets the group's directory reach and republishes. Private clears the
  /// public flag; 'local' lists it by proximity, 'global' in the worldwide
  /// feed.
  Future<void> setReach(
    String groupId, {
    required bool isPublic,
    String scope = 'local',
  }) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(isPublic: Value(isPublic), scope: Value(scope)),
    );
    await _publishFullMeta(groupId);
  }

  /// Archives the group locally, hiding it from the active list. Data is kept.
  Future<void> archiveGroup(String groupId) =>
      (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
        GroupsCompanion(archivedAt: Value(DateTime.now())),
      );

  /// Restores an archived group to the active list.
  Future<void> unarchiveGroup(String groupId) =>
      (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
        const GroupsCompanion(archivedAt: Value(null)),
      );

  /// Leaves a group: drops this device's membership and removes its local
  /// copy. The group lives on for other members.
  Future<void> leaveGroup(String groupId) async {
    await removeMember(groupId, currentUserId);
    await deleteGroup(groupId);
  }

  /// Removes the group and its local data from this device.
  Future<void> deleteGroup(String groupId) async {
    // Tear down the live subscription first so a rejoin builds a fresh one and
    // re-runs catch-up, instead of reusing a warm channel that could advance
    // the cursor past the group-meta and drop tags, area and points.
    await sync.stop(groupId);
    await (db.delete(
      db.messages,
    )..where((m) => m.groupId.equals(groupId))).go();
    await (db.delete(db.hotKeys)..where((h) => h.groupId.equals(groupId))).go();
    await (db.delete(
      db.groupMembers,
    )..where((m) => m.groupId.equals(groupId))).go();
    await db.clearOutboxFor(groupId);
    await db.clearCursor(groupId);
    await (db.delete(db.groups)..where((g) => g.id.equals(groupId))).go();
  }

  /// An admin's delete: purges the group's envelopes on the server, then drops
  /// the local copy. The public listing is cleared by the caller, which holds
  /// the directory. Members who still have the group keep only their own local
  /// copy afterwards.
  Future<void> deleteGroupForEveryone(String groupId) async {
    await sync.purgeRemote(groupId);
    await deleteGroup(groupId);
  }

  String inviteLinkFor(Group group) =>
      InviteLink(groupId: group.id, key: group.encKey).url;

  /// Joins via an invite link: stores the key, subscribes, pulls the group
  /// metadata and history, and announces this device's identity so it can be
  /// verified and promoted.
  Future<Group> joinViaLink(String link, IdentityKeys identity) async {
    final invite = InviteLink.parse(link);
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: invite.groupId,
            name: '',
            createdBy: '',
            encKey: invite.key,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await _addMembership(invite.groupId, role: 'member');
    await sync.start(invite.groupId);
    await announceIdentity(invite.groupId, identity);
    return (await db.groupById(invite.groupId))!;
  }

  /// Joins a group using a key delivered out of band (an approved join request
  /// sealed the key to this device), rather than from an invite link.
  Future<Group> joinWithKey(
    String groupId,
    String encKey,
    IdentityKeys identity,
  ) async {
    await db
        .into(db.groups)
        .insert(
          GroupsCompanion.insert(
            id: groupId,
            name: '',
            createdBy: '',
            encKey: encKey,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await _addMembership(groupId, role: 'member');
    await sync.start(groupId);
    await announceIdentity(groupId, identity);
    return (await db.groupById(groupId))!;
  }

  /// Invites a member to become an admin. The invite is signed by this device,
  /// so no other member can forge it; the member becomes an admin only after
  /// they accept. Returns false when the member has not shared an identity yet,
  /// so they cannot be promoted.
  Future<bool> inviteAdmin(
    String groupId,
    String inviteeId,
    IdentityKeys identity,
  ) async {
    final invitee = await db.profileById(inviteeId);
    final inviteePublic = invitee?.signingKey;
    if (inviteePublic == null) return false;
    await _publishAdminEvent(
      groupId: groupId,
      kind: 'invite',
      identity: identity,
      subjectId: inviteeId,
      subjectPublic: base64Decode(inviteePublic),
    );
    // Enrol the invitee in the server-readable admin set, authorised by this
    // admin, so the guard will honour their deletes once they act as admin.
    await adminRegistry?.submit(
      await signAdminStatement(
        signer: identity,
        groupId: groupId,
        adminPublic: base64Decode(inviteePublic),
      ),
    );
    return true;
  }

  /// Accepts a pending admin invitation, signing the acceptance so every member
  /// can verify it was this device that consented.
  Future<void> acceptAdmin(String groupId, IdentityKeys identity) =>
      _publishAdminEvent(
        groupId: groupId,
        kind: 'accept',
        identity: identity,
        subjectId: currentUserId,
        subjectPublic: null,
      );

  Future<void> _publishAdminEvent({
    required String groupId,
    required String kind,
    required IdentityKeys identity,
    required String subjectId,
    required Uint8List? subjectPublic,
  }) async {
    final unsigned = AdminEvent(
      kind: kind,
      groupId: groupId,
      actorId: currentUserId,
      actorPublic: identity.signingPublic,
      subjectId: subjectId,
      subjectPublic: subjectPublic,
      signature: Uint8List(0),
    );
    final signature = await identity.sign(unsigned.signedBytes());
    final id = await sync.publishControl(
      groupId: groupId,
      kind: kind == 'invite'
          ? MessageKind.adminInvite
          : MessageKind.adminAccept,
      body: {
        'actorPublic': base64Encode(identity.signingPublic),
        'subjectId': subjectId,
        if (subjectPublic != null) 'subjectPublic': base64Encode(subjectPublic),
        'signature': base64Encode(signature),
      },
    );
    await applyAdminEvent(
      db,
      id: id,
      groupId: groupId,
      seq: null,
      kind: kind,
      actorId: currentUserId,
      actorPublic: identity.signingPublic,
      subjectId: subjectId,
      subjectPublic: subjectPublic,
      signature: signature,
    );
  }

  /// Toggles whether joining requires an admin's approval, and republishes.
  Future<void> setJoinApproval(String groupId, {required bool value}) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(joinApproval: Value(value)),
    );
    await _publishFullMeta(groupId);
  }

  /// Toggles whether non-admins may export the group's data, and republishes.
  Future<void> setAllowMemberExport(
    String groupId, {
    required bool value,
  }) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(allowMemberExport: Value(value)),
    );
    await _publishFullMeta(groupId);
  }

  /// Toggles whether non-admins may place points by tapping the map, and
  /// republishes. When off they can still send their live GPS point.
  Future<void> setAllowMemberPlace(
    String groupId, {
    required bool value,
  }) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(allowMemberPlace: Value(value)),
    );
    await _publishFullMeta(groupId);
  }

  /// Toggles whether points may be sent from outside the mapping area, and
  /// republishes.
  Future<void> setAllowOutsideArea(
    String groupId, {
    required bool value,
  }) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(allowOutsideArea: Value(value)),
    );
    await _publishFullMeta(groupId);
  }

  /// Toggles whether every mapper must select a zone before dropping points,
  /// and republishes.
  Future<void> setRequireZone(
    String groupId, {
    required bool value,
  }) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(requireZone: Value(value)),
    );
    await _publishFullMeta(groupId);
  }

  /// Sets the accuracy cap (metres) a sent fix may carry, null to remove it,
  /// and republishes.
  Future<void> setGpsLimit(String groupId, int? meters) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(gpsLimitM: Value(meters)),
    );
    await _publishFullMeta(groupId);
  }

  /// Toggles whether non-admins may add, edit and remove quick tags, and
  /// republishes.
  Future<void> setAllowMemberTags(
    String groupId, {
    required bool value,
  }) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(allowMemberTags: Value(value)),
    );
    await _publishFullMeta(groupId);
  }

  /// Toggles whether members may switch a thread into chat mode, and
  /// republishes so every device learns the setting.
  Future<void> setAllowChatMode(
    String groupId, {
    required bool value,
  }) async {
    await (db.update(db.groups)..where((g) => g.id.equals(groupId))).write(
      GroupsCompanion(allowChatMode: Value(value)),
    );
    await _publishFullMeta(groupId);
  }

  /// Drops a member from the local roster. This does not rotate the group key,
  /// so it is a roster change only, not cryptographic exclusion.
  Future<void> removeMember(String groupId, String profileId) async {
    await (db.delete(db.groupMembers)..where(
          (m) => m.groupId.equals(groupId) & m.profileId.equals(profileId),
        ))
        .go();
  }

  Future<void> _addMembership(String groupId, {required String role}) async {
    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(id: currentUserId, phone: ''),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.groupMembers)
        .insert(
          GroupMembersCompanion.insert(
            groupId: groupId,
            profileId: currentUserId,
            role: Value(role),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
