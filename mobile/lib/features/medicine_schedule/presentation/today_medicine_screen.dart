import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../widgets/state_views.dart';
import '../domain/dose_display_status.dart';
import '../domain/medicine_schedule_models.dart';
import 'medicine_schedule_controller.dart';

/// Minimal date/time formatting without pulling in `intl` as a new
/// dependency — matches the project's existing "small, hand-rolled i18n"
/// approach (see `AppStrings`).
String _formatTime(DateTime dt) {
  final hour24 = dt.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) => '${_monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';

class TodaysMedicineScreen extends ConsumerStatefulWidget {
  const TodaysMedicineScreen({super.key});

  @override
  ConsumerState<TodaysMedicineScreen> createState() => _TodaysMedicineScreenState();
}

class _TodaysMedicineScreenState extends ConsumerState<TodaysMedicineScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget refresh on open; the stream providers below already
    // render instantly from the local cache, so this only ever improves
    // freshness, never blocks the first frame.
    Future.microtask(() => ref.read(refreshMedicineScheduleProvider)());
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final doseListAsync = ref.watch(todaysMedicineProvider);
    final routinesAsync = ref.watch(activeRoutinesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.todaysMedicine)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(refreshMedicineScheduleProvider)(),
        child: doseListAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            retryLabel: strings.retry,
            onRetry: () => ref.read(refreshMedicineScheduleProvider)(),
          ),
          data: (doses) {
            final activeRoutines = routinesAsync.valueOrNull ?? const [];
            if (doses.isEmpty && activeRoutines.isEmpty) {
              return ListView(
                // Wrapped in a scrollable so pull-to-refresh still works
                // on an empty state.
                children: [
                  const SizedBox(height: 80),
                  EmptyView(
                    message: strings.noMedicineToday,
                    icon: Icons.medication_outlined,
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (doses.isEmpty)
                  EmptyView(message: strings.noMedicineToday, icon: Icons.today_outlined)
                else
                  ...doses.map((d) => _DoseTile(dose: d, strings: strings)),
                const SizedBox(height: 24),
                Text(strings.myMedicineRoutines, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (activeRoutines.isEmpty)
                  EmptyView(message: strings.noActiveRoutines, icon: Icons.list_alt_outlined)
                else
                  ...activeRoutines.map((r) => _RoutineTile(routine: r)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DoseTile extends ConsumerWidget {
  const _DoseTile({required this.dose, required this.strings});

  final MedicineDoseModel dose;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = _formatTime(dose.scheduledAt);
    final display = computeDoseDisplayStatus(dose);
    final (icon, color, label) = switch (display) {
      DoseDisplayStatus.taken => (Icons.check_circle, Colors.green, strings.doseTaken),
      DoseDisplayStatus.missed => (Icons.cancel_outlined, Theme.of(context).colorScheme.error, strings.doseMissed),
      DoseDisplayStatus.due => (Icons.notifications_active_outlined, Colors.orange, strings.doseDue),
      DoseDisplayStatus.skipped => (Icons.block, Colors.grey, strings.doseMissed),
      DoseDisplayStatus.upcoming => (Icons.schedule, Colors.blueGrey, strings.doseUpcoming),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(dose.medicineName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${dose.dosage} • $time'),
            Row(
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 12)),
                if (dose.syncState != 'synced') ...[
                  const Text(' • ', style: TextStyle(fontSize: 12)),
                  Text(_syncStateLabel(dose.syncState, strings), style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
        trailing: dose.canMarkTaken
            ? FilledButton(
                onPressed: () => ref.read(markDoseTakenProvider)(dose.id),
                child: Text(strings.markAsTaken),
              )
            : null,
      ),
    );
  }

  String _syncStateLabel(String syncState, AppStrings strings) {
    return switch (syncState) {
      'pending' => strings.pendingSyncBadge,
      'syncing' => strings.syncingBadge,
      'failed' => strings.syncFailedBadge,
      _ => strings.syncedBadge,
    };
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.routine});

  final MedicineRoutineModel routine;

  @override
  Widget build(BuildContext context) {
    final range = routine.endDate == null
        ? _formatDate(routine.startDate)
        : '${_formatDate(routine.startDate)} – ${_formatDate(routine.endDate!)}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.medication_liquid_outlined),
        title: Text(routine.medicineName),
        subtitle: Text('${routine.dosage} • ${routine.frequency}\n$range'),
        isThreeLine: true,
      ),
    );
  }
}
