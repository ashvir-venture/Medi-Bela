import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
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
                icon: Icons.open_in_full,
                title: strings.overlayLabel,
                ok: status.overlayAllowed,
                okText: strings.overlayAllowed,
                problemText: strings.overlayDenied,
                actionLabel: strings.allowAction,
                onAction: service.requestOverlay,
              ),
              _CheckTile(
                icon: Icons.screen_lock_portrait_outlined,
                title: strings.fullScreenIntentLabel,
                ok: status.fullScreenAllowed,
                okText: strings.fullScreenIntentAllowed,
                problemText: strings.fullScreenIntentDenied,
                actionLabel: strings.allowAction,
                onAction: service.requestFullScreen,
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
              const SizedBox(height: 8),
              // Round 14: steps for this phone's maker (autostart, battery).
              const PhoneBrandSteps(),
              const SizedBox(height: 16),
              Text(strings.fullScreenFallback, style: Theme.of(context).textTheme.bodySmall),
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

/// The phone maker, read once (Build.MANUFACTURER through MainActivity).
final deviceBrandProvider = FutureProvider<String>((ref) => ref.watch(reminderStatusServiceProvider).deviceBrand());

/// Round 14: the autostart / battery steps for this phone's maker (Xiaomi,
/// Oppo / Realme, Vivo, Samsung, Tecno / Infinix / itel, Huawei / Honor,
/// OnePlus, or the general ones), with a button to the app's settings page.
class PhoneBrandSteps extends ConsumerWidget {
  const PhoneBrandSteps({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r14;
    final p = context.palette;
    final brand = ref.watch(deviceBrandProvider).valueOrNull ?? '';
    final steps = s.brandSteps[phoneFamily(brand)] ?? s.brandSteps['other']!;
    final shown = brand.isEmpty ? 'Android' : brand[0].toUpperCase() + brand.substring(1);
    return Card(
      key: const ValueKey('phone-brand-steps'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.brandTitle(shown), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(s.brandStepsHelp, style: TextStyle(color: p.muted, fontSize: 14)),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.primaryContainer, shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: TextStyle(color: p.onPrimaryContainer, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 15, height: 1.4))),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => ref.read(reminderStatusServiceProvider).openAppSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: Text(s.openPhoneSettings),
            ),
          ],
        ),
      ),
    );
  }
}
