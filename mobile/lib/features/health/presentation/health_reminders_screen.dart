import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../widgets/details_fields.dart' show formatYmd;
import '../../../widgets/state_views.dart';
import '../../care/presentation/reading_screen.dart' show testFormPath;
import '../domain/health_models.dart';
import 'health_controller.dart';

class HealthRemindersScreen extends ConsumerStatefulWidget {
  const HealthRemindersScreen({super.key});

  @override
  ConsumerState<HealthRemindersScreen> createState() => _HealthRemindersScreenState();
}

class _HealthRemindersScreenState extends ConsumerState<HealthRemindersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(refreshHealthRemindersProvider)());
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final dueAsync = ref.watch(dueHealthRemindersProvider);
    final upcomingAsync = ref.watch(upcomingHealthRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.healthReminders)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(refreshHealthRemindersProvider)(),
        child: dueAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            retryLabel: strings.retry,
            onRetry: () => ref.read(refreshHealthRemindersProvider)(),
          ),
          data: (due) {
            final upcoming = upcomingAsync.valueOrNull ?? const [];
            if (due.isEmpty && upcoming.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyView(message: strings.noHealthReminders, icon: Icons.favorite_outline),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      strings.notMedicalAdviceDisclaimer,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (due.isNotEmpty) ...[
                  Text(strings.dueReminders, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...due.map((r) => _ReminderTile(reminder: r)),
                  const SizedBox(height: 16),
                ],
                if (upcoming.isNotEmpty) ...[
                  Text(strings.upcomingReminders, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...upcoming.map((r) => _ReminderTile(reminder: r)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder});

  final HealthReminderModel reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final now = DateTime.now();
    final t = reminder.scheduledAt;
    final when = '${formatYmd(t)} • ${TimeOfDay.fromDateTime(t).format(context)}';
    final day = reminder.isTest ? reminder.testDayAt(now) : null;
    final lines = [
      if (reminder.isTest) when,
      if (day != null) strings.testDayOf(day, testReminderDays),
      reminder.mealTiming,
      reminder.description,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return Card(
      child: ListTile(
        leading: Icon(reminder.isTest ? Icons.biotech_outlined : Icons.favorite_border),
        title: Text(reminder.title),
        subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
        isThreeLine: lines.length > 1,
        onTap: reminder.isTest ? () => context.push('/test-reminder/${reminder.id}?day=${(day ?? 1) - 1}') : null,
        // Upcoming reminders can't be done yet (owner, 2026-10-31).
        trailing: reminder.canCompleteAt(now)
            ? FilledButton(
                onPressed: () => ref.read(completeHealthReminderProvider)(reminder.id),
                child: Text(reminder.isTest ? strings.testDoneAction : strings.markComplete),
              )
            // Round 16: a done test opens its result form (the linked test kind).
            : reminder.isTest && reminder.isCompleted
                ? TextButton(
                    onPressed: () => context.push(testFormPath(kind: reminder.testKindCode, done: true, reminderId: reminder.id)),
                    child: Text(strings.r15.addResult),
                  )
                : null,
      ),
    );
  }
}
