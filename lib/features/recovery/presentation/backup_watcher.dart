import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/auth/application/auth_state.dart';

/// Keeps the encrypted backup current once the user has backed up. Any change
/// to the set of joined groups re-uploads the bundle, so a restore always
/// brings back the latest groups without the user backing up again.
class BackupWatcher extends ConsumerStatefulWidget {
  const BackupWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BackupWatcher> createState() => _BackupWatcherState();
}

class _BackupWatcherState extends ConsumerState<BackupWatcher> {
  Set<String>? _lastGroupIds;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeGroupsProvider, (previous, next) {
      final ids = next.asData?.value.map((group) => group.id).toSet();
      if (ids == null) return;
      final changed = _lastGroupIds != null && !setEquals(_lastGroupIds, ids);
      _lastGroupIds = ids;
      if (changed) unawaited(_refresh());
    });
    return widget.child;
  }

  Future<void> _refresh() async {
    final backedUp =
        ref.read(sharedPreferencesProvider).getBool('recovery.backedUp') ??
        false;
    if (!backedUp) return;
    final state = ref.read(authControllerProvider);
    if (state is! AuthSignedIn) return;
    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      await ref
          .read(recoveryServiceProvider)
          .backUp(
            identity: identity,
            senderId: state.session.userId,
            username: state.session.username,
          );
    } on Exception catch (error) {
      // Best-effort: the last good backup stays and the next group change
      // retries, so a transient or offline failure needs no user action.
      debugPrint('backup refresh skipped: $error');
    }
  }
}
