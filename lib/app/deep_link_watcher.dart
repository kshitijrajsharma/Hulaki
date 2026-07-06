import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:fieldchat/app/providers.dart';
import 'package:fieldchat/features/groups/invite_link.dart';
import 'package:fieldchat/features/messaging/presentation/chat_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Joins the group carried by an invite link that opened the app, then shows
/// its thread. Handles both the launch link (cold start) and links that arrive
/// while the app is already open. Mounted only when signed in, so a link is
/// acted on once a device identity exists.
class DeepLinkWatcher extends ConsumerStatefulWidget {
  const DeepLinkWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeepLinkWatcher> createState() => _DeepLinkWatcherState();
}

class _DeepLinkWatcherState extends ConsumerState<DeepLinkWatcher> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _sub = _appLinks.uriLinkStream.listen(_handle);
    unawaited(_handleInitial());
  }

  Future<void> _handleInitial() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) await _handle(uri);
  }

  Future<void> _handle(Uri uri) async {
    if (_handling) return;
    final invite = InviteLink.tryParse(uri.toString());
    if (invite == null || !mounted) return;
    _handling = true;
    final navigator = Navigator.of(context);
    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      final joined = await ref
          .read(groupServiceProvider)
          .joinViaLink(invite.url, identity);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatThreadScreen(groupId: joined.id, groupName: joined.name),
        ),
      );
    } finally {
      _handling = false;
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
