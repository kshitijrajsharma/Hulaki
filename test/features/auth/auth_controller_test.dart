import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fieldchat/data/local/database.dart';
import 'package:fieldchat/data/local/database_provider.dart';
import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/auth/application/auth_state.dart';
import 'package:fieldchat/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(
  Map<String, Object> prefs, {
  LocalDatabase? db,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      if (db != null) databaseProvider.overrideWithValue(db),
    ],
  );
}

/// Waits for the async session restore in `build()` to leave the loading
/// state before the test asserts or acts.
Future<AuthState> _settle(ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final state = container.read(authControllerProvider);
    if (state is! AuthLoading) return state;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  return container.read(authControllerProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores signed-out when no username is stored', () async {
    final container = await _container(const {'session.userId': 'device-1'});
    expect(await _settle(container), isA<AuthSignedOut>());
  });

  test('restores signed-in when id and username are stored', () async {
    final container = await _container(const {
      'session.userId': 'device-1',
      'session.username': 'ward7',
    });
    final state = await _settle(container);
    expect(state, isA<AuthSignedIn>());
    expect((state as AuthSignedIn).session.username, 'ward7');
  });

  test('register claims the handle and writes the profile', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _container(const {}, db: db);
    final controller = container.read(authControllerProvider.notifier);
    await _settle(container);

    await controller.register('Ward7_Mapper');

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthSignedIn>());
    final session = (state as AuthSignedIn).session;
    expect(session.username, 'ward7_mapper');
    expect(session.userId, isNotEmpty);
    final profile = await db.profileByUsername('ward7_mapper');
    expect(profile, isNotNull);
    expect(profile!.id, session.userId);
  });

  test('register rejects a taken handle', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertProfile(
      ProfilesCompanion.insert(
        id: 'someone-else',
        phone: '',
        displayName: const Value('ward7'),
      ),
    );
    final container = await _container(const {}, db: db);
    final controller = container.read(authControllerProvider.notifier);
    await _settle(container);

    await expectLater(
      controller.register('ward7'),
      throwsA(isA<AuthException>()),
    );
  });

  test('register rejects a malformed username', () async {
    final db = LocalDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = await _container(const {}, db: db);
    final controller = container.read(authControllerProvider.notifier);
    await _settle(container);

    await expectLater(
      controller.register('ab'),
      throwsA(isA<AuthException>()),
    );
  });

  test('signOut returns to onboarding', () async {
    final container = await _container(const {
      'session.userId': 'device-1',
      'session.username': 'ward7',
    });
    final controller = container.read(authControllerProvider.notifier);

    await controller.signOut();
    expect(container.read(authControllerProvider), isA<AuthSignedOut>());
  });
}
