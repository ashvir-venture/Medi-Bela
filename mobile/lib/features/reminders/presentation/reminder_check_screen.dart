import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/state_views.dart';
import 'reminder_status_controller.dart';

/// Lists the phone settings reminders depend on, with a button to fix each
/// one. Granting exact alarms here takes effect on return: the app-resume
/// refresh (SessionServices) reschedules every reminder as exact.
class ReminderCheckScreen extends ConsumerWidget {
  const ReminderCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final service = ref.watch(reminderStatusServiceProvider);
    final statusAsync = ref.watch(reminderStatusProvider);

    return ReminderStatusRefresher(
      child: Scaffold(
        appBar: AppBar(title: Text(strings.reminderCheckTitle)),
        body: statusAsync.when(
          loading: () => const LoadingView(),
          error: (_, _) => const SizedBox.shrink(),
          data: (status) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(strings.reminderCheckHelp),
              const SizedBox(height: 16),
              _CheckTile(
                icon: Icons.notifications_outlined,
                title: strings.notificationsPermissionLabel,
                ok: status.notificationsAllowed,
                okText: strings.notificationsAllowed,
                problemText: strings.notificationsBlocked,
                severe: true,
                actionLabel: strings.allowAction,
                onAction: () async {
                  await service.requestNotifications();
                  ref.invalidate(reminderStatusProvider);
                },
              ),
              _CheckTile(
                icon: Icons.alarm_outlined,
                title: strings.exactAlarmLabel,
                ok: status.exactAlarmsAllowed,
                okText: strings.exactAlarmAllowed,
                problemText: strings.exactAlarmDenied,
                actionLabel: strings.allowAction,
                onAction: service.requestExactAlarms,
              ),
              _CheckTile(
                icon: Icons.battery_alert_outlined,
                title: strings.batteryLabel,
                ok: status.batteryUnrestricted,
                okText: strings.batteryUnrestricted,
                problemText: strings.batteryRestricted,
                actionLabel: strings.openSettingsAction,
                onAction: service.openBatterySettings,
              ),
              const SizedBox(height: 16),
              Text(
                strings.reminderVendorTip,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.icon,
    required this.title,
    required this.ok,
    required this.okText,
    required this.problemText,
    required this.actionLabel,
    required this.onAction,
    this.severe = false,
  });

  final IconData icon;
  final String title;
  final bool ok;
  final String okText;
  final String problemText;
  final String actionLabel;
  final VoidCallback onAction;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? AppTheme.primary
        : severe
            ? AppTheme.danger
            : AppTheme.warning;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle_outline : icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(ok ? okText : problemText, style: TextStyle(color: color)),
                ],
              ),
            ),
            if (!ok) ...[
              const SizedBox(width: 8),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
