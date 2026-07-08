import 'dart:async';

import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/auth/application/auth_state.dart';
import 'package:fieldchat/features/capture/compass_source.dart';
import 'package:fieldchat/features/capture/geolocator_gps_source.dart';
import 'package:fieldchat/features/capture/gps_source.dart';
import 'package:fieldchat/features/capture/live_location.dart';
import 'package:fieldchat/features/discovery/public_directory.dart';
import 'package:fieldchat/features/groups/group_member_view.dart';
import 'package:fieldchat/features/groups/group_service.dart';
import 'package:fieldchat/features/identity/device_identity_store.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:fieldchat/features/sync/blob_store.dart';
import 'package:fieldchat/features/sync/in_memory_transport.dart';
import 'package:fieldchat/features/sync/message_transport.dart';
import 'package:fieldchat/features/sync/sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The message relay. In-memory today; swapped for the Supabase-backed
/// transport once the project credentials are wired.
final transportProvider = Provider<MessageTransport>(
  (ref) => InMemoryTransport(),
);

final blobStoreProvider = Provider<BlobStore>((ref) => InMemoryBlobStore());

/// This device's identity keys, created once and kept in the platform keystore.
/// Overridden in tests with an ephemeral pair.
final deviceIdentityProvider = FutureProvider<IdentityKeys>(
  (ref) => DeviceIdentityStore(const FlutterSecureStorage()).loadOrCreate(),
);

final publicDirectoryProvider = Provider<PublicDirectory>(
  (ref) => InMemoryPublicDirectory(),
);

/// The running app's version and build, read from the platform at launch.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

final gpsSourceProvider = Provider<GpsSource>(
  (ref) => const GeolocatorGpsSource(),
);

final liveLocationSourceProvider = Provider<LiveLocationSource>(
  (ref) => const GeolocatorLiveLocationSource(),
);

/// The device's live location, driving the GPS strip and detail sheet. Starts
/// in loading until the first fix arrives. Auto-disposed so continuous GPS runs
/// only while a screen (or the background service) is actively using it.
// ignore: specify_nonobvious_property_types
final liveLocationProvider = StreamProvider.autoDispose<LiveLocation>(
  (ref) => ref.watch(liveLocationSourceProvider).watch(),
);

final compassSourceProvider = Provider<CompassSource>(
  (ref) => const FlutterCompassSource(),
);

/// The device compass heading, stamped onto a point at capture so its detail
/// can show which way the phone was facing.
final compassHeadingProvider = StreamProvider<double?>(
  (ref) => ref.watch(compassSourceProvider).headings(),
);

/// The signed-in user id. Read only from screens shown behind the auth gate.
final currentUserIdProvider = Provider<String>((ref) {
  final state = ref.watch(authControllerProvider);
  if (state is AuthSignedIn) return state.session.userId;
  throw StateError('No signed-in user');
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: ref.watch(databaseProvider),
    transport: ref.watch(transportProvider),
    blobStore: ref.watch(blobStoreProvider),
    currentUserId: ref.watch(currentUserIdProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final groupServiceProvider = Provider<GroupService>(
  (ref) => GroupService(
    db: ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
    currentUserId: ref.watch(currentUserIdProvider),
  ),
);

final activeGroupsProvider = StreamProvider<List<Group>>(
  (ref) => ref.watch(databaseProvider).watchActiveGroups(),
);

final archivedGroupsProvider = StreamProvider<List<Group>>(
  (ref) => ref.watch(databaseProvider).watchArchivedGroups(),
);

/// Groups pulling their initial history, so a freshly joined thread shows a
/// syncing state rather than looking empty.
final syncingGroupsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(syncServiceProvider).syncingGroups,
);

/// Live latest message per group, driving the chats list preview so it updates
/// as messages arrive.
// ignore: specify_nonobvious_property_types
final latestMessageProvider = StreamProvider.family<Message?, String>(
  (ref, groupId) => ref.watch(databaseProvider).watchLatestMessage(groupId),
);

/// Maps a sender id to their chosen username, so chat shows handles instead of
/// ids. Live, so names learned from incoming messages appear without a reload.
final profileNamesProvider = StreamProvider<Map<String, String>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchAllProfiles()
      .map(
        (profiles) => {
          for (final profile in profiles)
            if (profile.displayName != null) profile.id: profile.displayName!,
        },
      );
});

/// Live messages for a group. Reading it also starts sync for that group.
// ignore: specify_nonobvious_property_types
final messagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  groupId,
) {
  unawaited(ref.watch(syncServiceProvider).start(groupId));
  return ref.watch(databaseProvider).watchMessages(groupId);
});

// Family provider type is verbose; the declaration is clear in context.
// ignore: specify_nonobvious_property_types
final hotKeysProvider = StreamProvider.family<List<HotKey>, String>(
  (ref, groupId) => ref.watch(databaseProvider).watchHotKeysFor(groupId),
);

// Family provider type is verbose; the declaration is clear in context.
// ignore: specify_nonobvious_property_types
final groupMembersProvider =
    StreamProvider.family<List<GroupMemberView>, String>(
      (ref, groupId) => ref.watch(databaseProvider).watchMembersFor(groupId),
    );

/// Whether this device is a verified admin of the group, derived from the
/// roster. False until the roster loads. Gates admin-only controls.
// ignore: specify_nonobvious_property_types
final isGroupAdminProvider = Provider.family<bool, String>((ref, groupId) {
  final members =
      ref.watch(groupMembersProvider(groupId)).asData?.value ??
      const <GroupMemberView>[];
  final selfId = ref.watch(currentUserIdProvider);
  return members.any((m) => m.profileId == selfId && m.isAdmin);
});
