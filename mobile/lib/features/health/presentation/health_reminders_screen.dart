import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../widgets/state_views.dart';
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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.favorite_border),
        title: Text(reminder.title),
        subtitle: reminder.description != null ? Text(reminder.description!) : null,
        trailing: FilledButton(
          onPressed: () => ref.read(completeHealthReminderProvider)(reminder.id),
          child: Text(strings.markComplete),
        ),
      ),
    );
  }
}
