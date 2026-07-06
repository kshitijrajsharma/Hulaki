import 'package:fieldchat/features/auth/application/auth_providers.dart';
import 'package:fieldchat/features/settings/units.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _unitsKey = 'settings.units';

/// The chosen distance/elevation unit system, persisted on the device. Defaults
/// to metric until the user changes it on the Me screen.
class UnitsNotifier extends Notifier<UnitSystem> {
  @override
  UnitSystem build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_unitsKey);
    return stored == UnitSystem.imperial.name
        ? UnitSystem.imperial
        : UnitSystem.metric;
  }

  Future<void> set(UnitSystem units) async {
    state = units;
    await ref.read(sharedPreferencesProvider).setString(_unitsKey, units.name);
  }
}

final unitsProvider = NotifierProvider<UnitsNotifier, UnitSystem>(
  UnitsNotifier.new,
);
