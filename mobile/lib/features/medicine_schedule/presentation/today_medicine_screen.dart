import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../../../widgets/state_views.dart';
import '../../home/presentation/home_top.dart';
import '../../reminders/presentation/reminder_status_banner.dart';
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

    // Shown under the Medicines tab, whose app bar carries the title.
    return Scaffold(
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
                padding: const EdgeInsets.all(16),
                children: [
                  const ReminderStatusBanner(),
                  const SizedBox(height: 64),
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
                const ReminderStatusBanner(),
                // Round 14: how each of the last 7 days went.
                const WeekStrip(),
                const SizedBox(height: 12),
                if (doses.isEmpty)
                  EmptyView(message: strings.noMedicineToday, icon: Icons.today_outlined)
                else
                  ...doses.map((d) => _DoseTile(dose: d, strings: strings)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(strings.myMedicineRoutines, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go(AppRoutes.medicinesTabPath('mine')),
                      icon: const Icon(Icons.edit_note),
                      label: Text(strings.manageMedicines),
                    ),
                  ],
                ),
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
      DoseDisplayStatus.taken => (Icons.check_circle, context.palette.success, strings.doseTaken),
      DoseDisplayStatus.missed => (Icons.cancel_outlined, Theme.of(context).colorScheme.error, strings.doseMissed),
      DoseDisplayStatus.due => (Icons.notifications_active_outlined, context.palette.warning, strings.doseDue),
      DoseDisplayStatus.skipped => (Icons.block, context.palette.subtle, strings.doseMissed),
      DoseDisplayStatus.upcoming => (Icons.schedule, context.palette.subtle, strings.doseUpcoming),
    };

    final outcome = doseOutcome(dose);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(dose.medicineName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${dose.dosage} • $time'),
            // Round 14: On time / Late / Missed once it is decided.
            if (outcome != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: DoseOutcomeChip(outcome: outcome),
              ),
            Row(
              children: [
                if (outcome == null) Text(label, style: TextStyle(color: color, fontSize: 12)),
                if (dose.syncState != 'synced') ...[
                  const Text(' • ', style: TextStyle(fontSize: 12)),
                  Text(_syncStateLabel(dose.syncState, strings), style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
        // Only from the dose's time until 1 hour before the medicine's next
        // dose: an upcoming dose has no button (owner, 2026-10-31).
        trailing: dose.canMarkTakenAt(DateTime.now())
            ? FilledButton.icon(
                // A clear, large green button (owner: marking is a button, never a tap on the row).
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: context.palette.taken,
                  foregroundColor: context.palette.onTaken,
                ),
                onPressed: () => ref.read(markDoseTakenProvider)(dose.id),
                icon: const Icon(Icons.check),
                label: Text(strings.takenAction),
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

/// Round 14 (the demo's week row): the last 7 days, today last, each with a
/// dot: green = all taken, orange = something missed, none = nothing known.
class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final p = context.palette;
    final doses = ref.watch(lastWeekDosesProvider).valueOrNull ?? const <MedicineDoseModel>[];
    final isBangla = identical(strings, bnStrings);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const bnDays = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

    Widget day(int back) {
      final d = start.subtract(Duration(days: back));
      final mine = doses.where((x) =>
          x.scheduledAt.year == d.year && x.scheduledAt.month == d.month && x.scheduledAt.day == d.day);
      final missed = mine.any((x) => doseOutcome(x) == DoseOutcome.missed);
      final allTaken = mine.isNotEmpty && mine.every((x) => x.isTaken);
      final dot = missed ? p.warning : allTaken ? p.success : Colors.transparent;
      final isToday = back == 0;
      final label = isToday ? s.today : (isBangla ? bnDays : enDays)[d.weekday - 1];
      return Expanded(
        child: Container(
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isToday ? p.head : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 12, color: isToday ? p.surface2 : p.muted)),
              Text(isBangla ? bnDigits('${d.day}') : '${d.day}',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: isToday ? p.surface2 : p.ink)),
              const SizedBox(height: 2),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isToday && dot == Colors.transparent ? const Color(0xFF5CC8D4) : dot,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: s.thisWeek,
      child: Row(children: [for (var back = 6; back >= 0; back--) day(back)]),
    );
  }
}
