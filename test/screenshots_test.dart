@Tags(['golden'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/app/app.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/data/local/database_provider.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the screens to PNGs for visual review. Tagged `golden` so the
/// default test run and CI skip them. Regenerate with: just screenshots
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  PackageInfo.setMockInitialValues(
    appName: 'Hulaki',
    packageName: 'app.hulaki.hulaki',
    version: '0.0.1',
    buildNumber: '1',
    buildSignature: '',
  );
  setUpAll(_loadBundledFonts);

  const session = {
    'session.userId': 'device-1',
    'session.username': 'field_tester',
    // Skip the first-run intro so the shell renders and its screens are what
    // gets captured, not the onboarding carousel.
    'intro.seen': true,
  };

  testWidgets('welcome', (tester) async {
    await _pumpApp(tester);
    await _capture(tester, 'welcome');
  });

  testWidgets('empty chats', (tester) async {
    await _pumpApp(tester, prefs: session);
    await _capture(tester, 'empty_chats');
  });

  testWidgets('chats home with a group', (tester) async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    await _pumpApp(tester, prefs: session, db: db);
    await _capture(tester, 'chats_home');
  });

  testWidgets('chat thread', (tester) async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    await _pumpApp(tester, prefs: session, db: db);
    await tester.tap(find.text('Ward 7 · Litter survey'));
    await _settle(tester);
    await _capture(tester, 'chat_thread');
  });

  // Point detail embeds a live map, which cannot render in a headless golden
  // run; its layout is reviewed on-device, as with the full map screen.

  testWidgets('group info', (tester) async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    await _pumpApp(tester, prefs: session, db: db);
    await tester.tap(find.text('Ward 7 · Litter survey'));
    await _settle(tester);
    await tester.tap(find.text('Ward 7 · Litter survey').last);
    await _settle(tester);
    await _capture(tester, 'group_info');
  });

  testWidgets('create group', (tester) async {
    await _pumpApp(tester, prefs: session);
    await tester.tap(find.text('Start a new group'));
    await _settle(tester);
    await _capture(tester, 'create_group');
  });

  testWidgets('join group', (tester) async {
    await _pumpApp(tester, prefs: session);
    await tester.tap(find.text('Join with a link'));
    await _settle(tester);
    await _capture(tester, 'join_group');
  });

  testWidgets('me', (tester) async {
    await _pumpApp(tester, prefs: session);
    await tester.tap(find.text('Me'));
    await _settle(tester);
    await _capture(tester, 'me');
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  LocalDatabase? db,
}) async {
  final database = db ?? LocalDatabase(NativeDatabase.memory());
  if (db == null) addTearDown(database.close);
  tester.view.devicePixelRatio = 2;
  await tester.binding.setSurfaceSize(const Size(390, 844));
  _mockPlugins(tester);
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(database),
      ],
      child: const HulakiApp(),
    ),
  );
  await _settle(tester);
}

/// Silences the platform plugins the shell and thread touch (deep links,
/// compass, location) so a headless golden run does not throw
/// MissingPluginException. Streams stay empty and lookups return nothing, which
/// renders the neutral "locating" states.
void _mockPlugins(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  for (final channel in const [
    'com.llfbandit.app_links/messages',
    'com.llfbandit.app_links/events',
    'hemanthraj/flutter_compass',
    'flutter.baseflow.com/geolocator',
    'flutter.baseflow.com/geolocator_updates',
    'flutter.baseflow.com/geolocator_service_updates',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => null,
    );
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 14]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  // Unmount so the drift stream's zero-duration close timer fires before the
  // end-of-test invariant check.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _seed(LocalDatabase db) async {
  const groupId = 'seed-group';
  const me = 'device-1';
  await db
      .into(db.groups)
      .insert(
        GroupsCompanion.insert(
          id: groupId,
          name: 'Ward 7 · Litter survey',
          createdBy: me,
          encKey: '',
        ),
      );
  await db.upsertProfile(
    ProfilesCompanion.insert(
      id: me,
      phone: '',
      displayName: const Value('field_tester'),
    ),
  );
  await db
      .into(db.groupMembers)
      .insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          profileId: me,
          role: const Value('admin'),
        ),
      );
  await db
      .into(db.hotKeys)
      .insert(
        HotKeysCompanion.insert(
          id: 'hk-trash',
          groupId: groupId,
          label: 'Trash',
          colorValue: 0xFF15181B,
        ),
      );
  await db
      .into(db.hotKeys)
      .insert(
        HotKeysCompanion.insert(
          id: 'hk-pole',
          groupId: groupId,
          label: 'Pole',
          colorValue: 0xFFC4615E,
          position: const Value(1),
        ),
      );
  await db
      .into(db.messages)
      .insert(
        MessagesCompanion.insert(
          id: 'm1',
          groupId: groupId,
          senderId: 'asha',
          kind: 'text',
          body: const Value('Overflowing bin near gate'),
          tagId: const Value('hk-trash'),
          lat: const Value(27.7051),
          lng: const Value(85.3051),
          accuracyM: const Value(6),
          sendState: const Value('sent'),
          createdAt: DateTime.now().subtract(const Duration(seconds: 3)),
        ),
      );
  await db
      .into(db.messages)
      .insert(
        MessagesCompanion.insert(
          id: 'm2',
          groupId: groupId,
          senderId: me,
          kind: 'text',
          body: const Value('Leaning pole on the corner'),
          tagId: const Value('hk-pole'),
          lat: const Value(27.7052),
          lng: const Value(85.3052),
          accuracyM: const Value(4),
          sendState: const Value('sent'),
          createdAt: DateTime.now(),
        ),
      );
}

Future<void> _loadBundledFonts() async {
  final fonts = <String, String>{
    'HankenGrotesk': 'assets/fonts/HankenGrotesk.ttf',
    'Caveat': 'assets/fonts/Caveat.ttf',
  };
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    fonts['MaterialIcons'] =
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf';
  }
  for (final entry in fonts.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader(entry.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
