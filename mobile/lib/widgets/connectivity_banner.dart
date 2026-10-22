import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';
import '../core/theme/app_theme.dart';
import '../providers/core_providers.dart';

/// Shows "You're offline" when there's no connection, or "Syncing…"
/// while the outbox is draining. Hidden entirely when online and idle, so
/// it never distracts from the actual content underneath.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final isOnlineAsync = ref.watch(connectivityStreamProvider);
    final isOnline = isOnlineAsync.value ?? true;

    if (!isOnline) {
      return _Banner(
        text: strings.offlineBanner,
        color: AppTheme.warning,
        icon: Icons.cloud_off_outlined,
      );
    }

    final syncService = ref.watch(syncServiceProvider);
    return StreamBuilder<bool>(
      stream: syncService.isSyncing,
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return _Banner(
            text: strings.syncingBanner,
            color: AppTheme.primary,
            icon: Icons.sync,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
