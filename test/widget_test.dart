import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fieldchat/app/app.dart';
import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/capture/gps_source.dart';
import 'package:fieldchat/features/capture/live_location.dart';
import 'package:fieldchat/features/chats/chats_home_screen.dart';
import 'package:fieldchat/features/identity/identity_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _session = {
  'session.userId': 'device-1',
  'session.username': 'field_tester',
};

Future<LocalDatabase> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final db = LocalDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        gpsSourceProvider.overrideWithValue(FakeGpsSource()),
        liveLocationSourceProvider.overrideWithValue(
          const FakeLiveLocationSource(),
        ),
        deviceIdentityProvider.overrideWith((ref) => IdentityKeys.generate()),
      ],
      child: const FieldChatApp(),
    ),
  );
  await _settle(tester);
  return db;
}

/// Bounded pumps instead of pumpAndSettle: text-field cursors and loading
/// spinners animate indefinitely and never "settle".
Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmounts the tree so provider subscriptions and any auto-dispose timers
/// tear down before the end-of-test invariant check.
Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('a fresh launch shows the username onboarding', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Welcome to FieldChat'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('a restored session lands on the Chats shell', (tester) async {
    await _pumpApp(tester, prefs: _session);
    expect(find.byType(ChatsHomeScreen), findsOneWidget);
    expect(find.text('FieldChat'), findsOneWidget);
    expect(find.text('No groups yet'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('picking a username signs in and shows the shell', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.text('Welcome to FieldChat'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ward7_mapper');
    await tester.tap(find.text('Continue'));
    await _settle(tester);

    expect(find.byType(ChatsHomeScreen), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('create a group, send a message, and see it in the thread', (
    tester,
  ) async {
    await _pumpApp(tester, prefs: _session);

    await tester.tap(find.text('Start a new group'));
    await _settle(tester);
    expect(find.text('New mapping group'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Ward 7 · Litter survey',
    );
    await tester.pump();
    await tester.tap(find.text('Create group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // A fresh thread's header shows the point tally, which starts empty.
    expect(find.text('No points yet'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('composer-field')),
      'Overflowing bin near gate',
    );
    await tester.tap(find.byIcon(Icons.send));

    var appeared = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Overflowing bin near gate').evaluate().isNotEmpty) {
        appeared = true;
        break;
      }
    }
    expect(appeared, isTrue);
    await _dispose(tester);
  });

  testWidgets('join with a link opens the group thread', (tester) async {
    await _pumpApp(tester, prefs: _session);

    await tester.tap(find.text('Join with a link'));
    await _settle(tester);
    expect(find.text('Paste an invite link'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'https://fieldchat.app/g/g-join#key123',
    );
    await tester.tap(find.text('Join'));
    await _settle(tester);

    expect(find.text('No points yet'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('join rejects a link that is not an invite', (tester) async {
    await _pumpApp(tester, prefs: _session);

    await tester.tap(find.text('Join with a link'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'https://example.com');
    await tester.tap(find.text('Join'));
    await _settle(tester);

    expect(find.text('That is not a FieldChat invite link.'), findsOneWidget);
    await _dispose(tester);
  });
}
