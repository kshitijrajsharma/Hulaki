import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/features/groups/presentation/group_info_screen.dart';
import 'package:hulaki/l10n/app_localizations.dart';

/// Raises a local notification for each new pending join request to a group
/// this device administers, polling while the app is alive.
class JoinRequestWatcher extends ConsumerStatefulWidget {
  const JoinRequestWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<JoinRequestWatcher> createState() => _JoinRequestWatcherState();
}

class _JoinRequestWatcherState extends ConsumerState<JoinRequestWatcher> {
  static const _interval = Duration(seconds: 25);
  Timer? _timer;
  StreamSubscription<String>? _tapSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifications = ref.read(localNotificationsProvider);
      unawaited(notifications.init());
      _tapSub = notifications.onTap.listen(_openRequests);
      unawaited(_poll());
      _timer = Timer.periodic(_interval, (_) => unawaited(_poll()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_tapSub?.cancel());
    super.dispose();
  }

  void _openRequests(String groupId) {
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupInfoScreen(groupId: groupId),
        ),
      ),
    );
  }

  Future<void> _poll() async {
    final l10n = AppLocalizations.of(context);
    final notifications = ref.read(localNotificationsProvider);
    for (final (group, request)
        in await ref.read(joinRequestPollerProvider).poll()) {
      await notifications.show(
        id: request.id.hashCode,
        title: l10n.joinRequestNotifyTitle,
        body: l10n.joinRequestNotifyBody(
          request.requesterName ?? l10n.joinRequestNotifySomeone,
          group.name,
        ),
        payload: group.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
