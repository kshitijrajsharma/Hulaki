import 'package:fieldchat/design/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is online. A manual flag today; wired to connectivity_plus
/// with the device-sensor milestone. Sync reads this to gate sending.
class OnlineNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  bool get online => state;
  set online(bool value) => state = value;
}

// NotifierProvider type is verbose; the declaration is clear in context.
final onlineProvider = NotifierProvider<OnlineNotifier, bool>(
  OnlineNotifier.new,
);

/// The thin "you are offline" strip. The only thing that changes when the
/// network drops: keep mapping, it syncs when you are back.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(onlineProvider)) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFFFBEFD6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 14, color: AppColors.amberText),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'You are offline. Keep mapping, it syncs when you are back.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.amberText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
