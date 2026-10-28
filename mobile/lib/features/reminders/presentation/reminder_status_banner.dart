import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import 'reminder_status_controller.dart';

/// Warns when reminders are blocked (red) or may be late because exact
/// alarms aren't allowed (gentle). Hidden when everything is fine. Tapping
/// opens the Reminder check screen.
class ReminderStatusBanner extends ConsumerWidget {
  const ReminderStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReminderStatusRefresher(
      child: Builder(
        builder: (context) {
          final strings = ref.watch(stringsProvider);
          final status = ref.watch(reminderStatusProvider).valueOrNull;
          if (status == null || (!status.blocked && !status.mayBeLate)) {
            return const SizedBox.shrink();
          }
          final color = status.blocked ? AppTheme.danger : AppTheme.warning;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push(AppRoutes.reminderCheck),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        status.blocked
                            ? Icons.notifications_off_outlined
                            : Icons.schedule_outlined,
                        color: color,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          status.blocked
                              ? strings.remindersBlockedBanner
                              : strings.remindersMayBeLateBanner,
                          style: TextStyle(color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: color),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
