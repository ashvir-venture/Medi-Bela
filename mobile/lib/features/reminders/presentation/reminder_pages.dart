import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../notifications/notification_scheduler.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/details_fields.dart' show formatYmd;
import '../../../widgets/first_use_tips.dart';
import '../../health/domain/health_models.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../../prescription/presentation/confirm_prescription_screen.dart' show formatHhmm;

/// The medicines due at [at] with large Later (red) and Taken (green)
/// buttons, which work like the notification's own (Taken marks the whole
/// time taken, inside each dose's window; Later rings again in 15 minutes,
/// never after the 4th ring). Opened over other apps / the lock screen by a
/// ringing reminder, or by tapping one ([alarm]: only the buttons close it).
class DoseReminderScreen extends ConsumerWidget {
  const DoseReminderScreen({super.key, required this.at, this.stage = 0, this.alarm = false});

  final DateTime at;
  final int stage;
  final bool alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final doses = ref.watch(_dosesAtProvider(at));
    final now = DateTime.now();
    final list = doses.valueOrNull ?? const <MedicineDoseModel>[];
    final open = list.where((d) => d.canMarkTakenAt(now)).toList();
    final pending = list.where((d) => d.status == 'PENDING' || d.status == 'MISSED').toList();
    final group = ReminderGroup(at, const []);
    final laterAllowed = open.isNotEmpty && !group.isLastRing(stage, now) && now.isBefore(group.lastRingAt);

    return _ReminderScaffold(
      icon: Icons.medication_outlined,
      image: 'assets/images/medicine_image.png',
      title: strings.reminderTitle,
      when: TimeOfDay.fromDateTime(at).format(context),
      strings: strings,
      alarm: alarm,
      doneLabel: strings.takenAction,
      body: [
        // Round 17: a first-use tip in the page (never over the buttons).
        const InlineFirstUseTips(screen: TipsScreen.reminder),
        for (final d in list)
          Card(
            child: ListTile(
              leading: Icon(
                d.isTaken ? Icons.check_circle : Icons.medication_outlined,
                color: d.isTaken ? context.palette.success : null,
              ),
              title: Text(d.medicineName, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                d.isTaken ? '${d.dosage} • ${strings.doseTaken}' : d.dosage,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        if (list.isNotEmpty && pending.isEmpty) _Notice(text: strings.reminderAllTaken),
        if (pending.isNotEmpty && open.isEmpty)
          _Notice(text: now.isBefore(at) ? strings.reminderNotDueYet : strings.errorDoseWindowClosed),
      ],
      onDone: open.isEmpty
          ? null
          : () async {
              final repo = ref.read(medicineScheduleRepositoryProvider);
              for (final d in open) {
                await repo.markDoseTaken(d.id);
              }
              await ref.read(notificationSchedulerProvider).reconcileFromCache();
              if (context.mounted) await _close(context, alarm);
              await ref.read(syncServiceProvider).drainQueue();
            },
      laterLabel: strings.reminderLaterAction,
      onLater: laterAllowed
          ? () async {
              await ref.read(notificationSchedulerProvider).snooze(at, stage);
              if (context.mounted) await _close(context, alarm);
            }
          : null,
    );
  }
}

final _dosesAtProvider = StreamProvider.autoDispose.family<List<MedicineDoseModel>, DateTime>(
  (ref, at) => ref.watch(medicineScheduleRepositoryProvider).watchAt(at),
);

/// A test reminder: the test, its date and time, meal timing and note, with
/// Done (green) and, before the third day, "Remind me tomorrow" (red). Full
/// screen when a ring opened it ([alarm]).
class TestReminderScreen extends ConsumerWidget {
  const TestReminderScreen({super.key, required this.reminderId, this.day = 0, this.alarm = false});

  final String reminderId;
  final int day;
  final bool alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final reminder = ref.watch(_testReminderProvider(reminderId)).valueOrNull;
    final now = DateTime.now();
    final canDone = reminder != null && reminder.canCompleteAt(now);
    final testDay = reminder?.testDayAt(now);

    return _ReminderScaffold(
      icon: Icons.biotech_outlined,
      image: 'assets/images/medical_test.png',
      title: reminder?.title ?? strings.testReminderTitle,
      when: reminder == null
          ? ''
          : '${formatYmd(reminder.scheduledAt)} • ${formatHhmm(context, _hhmm(reminder.scheduledAt))}',
      strings: strings,
      alarm: alarm,
      doneLabel: strings.testDoneAction,
      body: [
        if (reminder != null) ...[
          if (testDay != null && reminder.status == 'PENDING')
            Text(strings.testDayOf(testDay, testReminderDays), style: Theme.of(context).textTheme.titleMedium),
          if (reminder.mealTiming != null) _Detail(icon: Icons.restaurant_outlined, text: reminder.mealTiming!),
          if (reminder.description?.isNotEmpty ?? false)
            _Detail(icon: Icons.notes_outlined, text: reminder.description!),
          if (reminder.isCompleted) _Notice(text: strings.testDoneStatus),
          if (reminder.status == 'MISSED') _Notice(text: strings.doseMissed),
          if (reminder.isUpcoming) _Notice(text: strings.reminderNotDueYet),
        ],
      ],
      onDone: canDone
          ? () async {
              final done = await ref.read(healthReminderRepositoryProvider).markComplete(reminderId);
              if (context.mounted) await _close(context, alarm);
              if (done) await ref.read(syncServiceProvider).drainQueue();
            }
          : null,
      laterLabel: strings.testLaterAction,
      onLater: canDone && day < testReminderDays - 1
          ? () async {
              await ref.read(notificationSchedulerProvider).dismissTestReminderDay(reminderId, day);
              if (context.mounted) await _close(context, alarm);
            }
          : null,
    );
  }

  static String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

final _testReminderProvider = StreamProvider.autoDispose.family<HealthReminderModel?, String>(
  (ref, id) => ref.watch(healthReminderRepositoryProvider).watchById(id),
);

const _alarmChannel = MethodChannel('com.carebridge.app/reminder_status');

/// Leaves the page. A full screen Android opened over the lock screen or
/// another app goes back there (MainActivity.finishAlarm); otherwise back to
/// where the user was, or Home.
Future<void> _close(BuildContext context, bool alarm) async {
  var movedBack = false;
  if (alarm && defaultTargetPlatform == TargetPlatform.android) {
    try {
      movedBack = await _alarmChannel.invokeMethod<bool>('finishAlarm') ?? false;
    } catch (_) {}
  }
  if (!context.mounted) return;
  if (!movedBack && context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}

/// The full-screen card: picture on top ([image]: medicine_image.png for a
/// medicine, medical_test.png for a test; the icon until it loads),
/// the reminder text, then two large buttons side by side: Later (red) and
/// Taken / Done (green). In [alarm] mode nothing but those buttons closes it
/// (no close button, Back does nothing); when there is nothing left to do a
/// Close button appears instead.
class _ReminderScaffold extends StatelessWidget {
  const _ReminderScaffold({
    required this.icon,
    required this.title,
    required this.when,
    required this.strings,
    required this.body,
    required this.onDone,
    required this.doneLabel,
    required this.laterLabel,
    required this.onLater,
    required this.image,
    this.alarm = false,
  });

  /// The picture on top (assets/images/...).
  final String image;
  final IconData icon;
  final String title;
  final String when;
  final AppStrings strings;
  final List<Widget> body;
  final VoidCallback? onDone;
  final String doneLabel;
  final String laterLabel;
  final VoidCallback? onLater;
  final bool alarm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    const big = Size(0, 72);
    final nothingToDo = onDone == null && onLater == null;
    return PopScope(
      canPop: !alarm,
      child: Scaffold(
        appBar: alarm
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: strings.close,
                  onPressed: () => _close(context, false),
                ),
              ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  image,
                  height: 200,
                  fit: BoxFit.contain,
                  // Until the picture is added: the icon.
                  errorBuilder: (_, _, _) => Icon(icon, size: 96, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              if (when.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  when,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 20),
              ...body,
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: nothingToDo
                ? FilledButton(
                    style: FilledButton.styleFrom(minimumSize: big, textStyle: theme.textTheme.titleLarge),
                    onPressed: () => _close(context, alarm),
                    child: Text(strings.close),
                  )
                : Row(
                    children: [
                      if (onLater != null) ...[
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: big,
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              textStyle: theme.textTheme.titleLarge,
                            ),
                            onPressed: onLater,
                            icon: const Icon(Icons.snooze, size: 28),
                            label: Text(laterLabel, textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: big,
                            backgroundColor: palette.success,
                            foregroundColor: theme.colorScheme.onError,
                            textStyle: theme.textTheme.titleLarge,
                          ),
                          onPressed: onDone,
                          icon: const Icon(Icons.check, size: 28),
                          label: Text(doneLabel),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.palette.muted, fontSize: 16)),
      );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      );
}
