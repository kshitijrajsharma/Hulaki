import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:hulaki/data/local/database.dart';
import 'package:hulaki/features/onboarding/demo_group.dart';
import 'package:hulaki/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  setUp(() => db = LocalDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('newcomer joins the demo as a member, with export left on', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final groupId = await seedDemoGroup(
      db,
      'user-1',
      l10n,
      centerLat: 27.7,
      centerLng: 85.3,
    );

    final group = await db.groupById(groupId);
    expect(group, isNotNull);
    expect(group!.allowMemberExport, isTrue);
    expect(group.allowMemberTags, isFalse);
    expect(group.createdBy, 'demo-ashi');

    final members = await db.watchMembersFor(groupId).first;
    expect(members.firstWhere((m) => m.profileId == 'user-1').isAdmin, isFalse);
    expect(
      members.firstWhere((m) => m.profileId == 'demo-ashi').isAdmin,
      isTrue,
    );
  });
}
