import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock_label.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../../widgets/pill_icon.dart';
import '../../../widgets/state_views.dart';
import '../../home/presentation/home_top.dart' show DoseOutcomeChip;
import '../../reminders/presentation/reminder_status_banner.dart';
import '../domain/dose_display_status.dart';
import '../domain/medicine_schedule_models.dart';
import 'medicine_schedule_controller.dart';
import 'my_medicines_screen.dart' show managedRoutinesProvider;
import 'routine_form_screen.dart';
import 'today_medicine_screen.dart' show WeekStrip;

/// Round 18 (client note point 7): one "My medicine" page instead of Today
/// and My medicines. Previous / next day arrows on top, that day's doses by
/// morning / afternoon / night with Taken, the "when needed" medicines with
/// "Took one now", then every medicine on one line ("taken 26 of 30 days")
/// that opens its own page.
class MyMedicineScreen extends ConsumerStatefulWidget {
  const MyMedicineScreen({super.key});

  @override
  ConsumerState<MyMedicineScreen> createState() => _MyMedicineScreenState();
}

class _MyMedicineScreenState extends ConsumerState<MyMedicineScreen> {
  late DateTime _day = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(refreshMedicineScheduleProvider)());
  }

  void _shift(int days) => setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _openAdd() async {
    final changed = await context.push<bool>(AppRoutes.medicineForm, extra: const RoutineFormArgs());
    if (changed == true) ref.invalidate(managedRoutinesProvider(null));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final p = context.palette;
    final today = DateUtils.dateOnly(DateTime.now());
    final doses = ref.watch(dayDosesProvider(_day));
    final routines = ref.watch(managedRoutinesProvider(null)).valueOrNull;
    final month = ref.watch(last30DaysDosesProvider).valueOrNull ?? const <MedicineDoseModel>[];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(refreshMedicineScheduleProvider)();
        ref.invalidate(managedRoutinesProvider(null));
        ref.invalidate(last30DaysDosesProvider);
      },
      child: ListView(
        // Bottom room for the AI button (tab root).
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const ReminderStatusBanner(),
          const WeekStrip(),
          const SizedBox(height: 8),
          Row(children: [
            IconButton(
              key: const ValueKey('day-prev'),
              tooltip: s.prevDay,
              onPressed: _day.isAfter(today.subtract(const Duration(days: 30))) ? () => _shift(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                s.dayLabel(_day, DateTime.now()),
                key: const ValueKey('day-label'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('day-next'),
              tooltip: s.nextDay,
              onPressed: _day.isBefore(today.add(const Duration(days: 6))) ? () => _shift(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
          doses.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorView(message: friendlyErrorMessage(e), retryLabel: strings.retry, onRetry: () => ref.invalidate(dayDosesProvider(_day))),
            data: (list) => _DayDoses(doses: list, strings: strings, isToday: _day == today),
          ),
          if (routines != null && routines.any((r) => r.asNeeded)) ...[
            const SizedBox(height: 16),
            Text(s.whenNeededTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in routines.where((r) => r.asNeeded)) AsNeededCard(routine: r),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text(s.myMedicines, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          if (routines == null)
            Text(strings.needsInternetToSave, style: TextStyle(color: p.muted, fontSize: AppType.small))
          else if (routines.isEmpty)
            EmptyView(message: strings.noActiveRoutines, icon: Icons.medication_outlined)
          else
            Card(
              child: Column(children: [
                for (var i = 0; i < routines.length; i++)
                  MedicineLine(routine: routines[i], month: month, divider: i > 0),
              ]),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('my-medicine-add'),
            onPressed: _openAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(strings.addMedicine),
          ),
        ],
      ),
    );
  }
}

/// One day's doses grouped by morning / afternoon / night.
class _DayDoses extends ConsumerWidget {
  const _DayDoses({required this.doses, required this.strings, required this.isToday});

  final List<MedicineDoseModel> doses;
  final AppStrings strings;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings.r18;
    final p = context.palette;
    if (doses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(s.noDosesThisDay, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
      );
    }
    final taken = doses.where((d) => d.isTaken).length;
    final groups = <DaySlot, List<MedicineDoseModel>>{};
    for (final d in doses) {
      (groups[slotOf(_hhmm(d.scheduledAt))] ??= []).add(d);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.dosesOfDay(taken, doses.length), textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: AppType.small)),
      const SizedBox(height: 8),
      for (final slot in DaySlot.values)
        if (groups[slot] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    SlotBadge(hhmm: _hhmm(groups[slot]!.first.scheduledAt), size: 30),
                    const SizedBox(width: 10),
                    Text(slotName(s, _hhmm(groups[slot]!.first.scheduledAt)), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  for (final d in groups[slot]!) _DoseRow(dose: d, strings: strings),
                ]),
              ),
            ),
          ),
    ]);
  }

  static String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _DoseRow extends ConsumerWidget {
  const _DoseRow({required this.dose, required this.strings});

  final MedicineDoseModel dose;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final outcome = doseOutcome(dose);
    final canTake = dose.canMarkTakenAt(DateTime.now());
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dose.medicineName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${TimeOfDay.fromDateTime(dose.scheduledAt).label(context)} · ${dose.dosage}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: AppType.small)),
          ]),
        ),
        if (canTake)
          FilledButton.icon(
            key: ValueKey('take-${dose.id}'),
            style: FilledButton.styleFrom(backgroundColor: p.taken, foregroundColor: p.onTaken),
            onPressed: () => ref.read(markDoseTakenProvider)(dose.id),
            icon: const Icon(Icons.check_rounded),
            label: Text(strings.takenAction),
          )
        else if (outcome != null)
          DoseOutcomeChip(outcome: outcome)
        else if (dose.isTaken)
          Icon(Icons.check_circle_rounded, color: p.taken)
        else
          Icon(Icons.schedule_rounded, color: p.muted),
      ]),
    );
  }
}

/// Round 18: an as-needed medicine with "Took one now" (client point 1b).
/// Online; warns over the daily most or inside the gap, but always logs.
class AsNeededCard extends ConsumerStatefulWidget {
  const AsNeededCard({super.key, required this.routine, this.forUserId});

  final ManagedRoutine routine;
  final String? forUserId;

  @override
  ConsumerState<AsNeededCard> createState() => _AsNeededCardState();
}

class _AsNeededCardState extends ConsumerState<AsNeededCard> {
  bool _busy = false;
  List<DateTime>? _today;

  Future<void> _took() async {
    final s = ref.read(stringsProvider).r18;
    setState(() => _busy = true);
    try {
      final r = await ref.read(medicineScheduleApiProvider).tookAsNeeded(widget.routine.id, forUserId: widget.forUserId, takenAt: DateTime.now());
      if (!mounted) return;
      setState(() => _today = r.takenToday);
      final msg = r.overMax ? s.overMaxWarn : r.tooSoon ? s.tooSoonWarn : s.logged;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      // The box counts it too.
      ref.read(medicineBoxRepositoryProvider).refreshFromServer().ignore();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider).r18;
    final p = context.palette;
    final r = widget.routine;
    final times = _today ?? r.takenToday;
    return Card(
      key: ValueKey('as-needed-${r.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          PillIcon(color: r.pillColor, shape: r.pillShape, formName: r.formName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.medicineName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                times.isEmpty ? s.notTakenToday : s.takenAtTimes(times.map((t) => TimeOfDay.fromDateTime(t).label(context)).join(', ')),
                style: TextStyle(color: p.muted, fontSize: AppType.small),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: ValueKey('took-${r.id}'),
            onPressed: _busy ? null : _took,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(s.tookOneNow),
          ),
        ]),
      ),
    );
  }
}

/// One medicine on one line (client point 6): look, name, how often and
/// "taken x of y days"; opens the medicine's page.
class MedicineLine extends ConsumerWidget {
  const MedicineLine({super.key, required this.routine, required this.month, this.divider = false, this.forUserId, this.memberName});

  final ManagedRoutine routine;
  final List<MedicineDoseModel> month;
  final bool divider;
  final String? forUserId;
  final String? memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r18;
    final p = context.palette;
    final (x, y) = takenDays(routine.id, month);
    final how = routine.asNeeded
        ? s.asNeededTag
        : routine.weekdays.isNotEmpty
            ? s.onDays(routine.weekdays.map((d) => s.weekdayShort[d]).join(', '))
            : routine.intervalDays > 1
                ? s.everyNDays(routine.intervalDays)
                : s.everyDayTimes(routine.scheduleTimes.length);
    final second = [how, if (!routine.asNeeded && y > 0) s.takenDaysOf(x, y)].join(' · ');
    return InkWell(
      key: ValueKey('medicine-line-${routine.id}'),
      onTap: () => context.push(AppRoutes.medicinePath(routine.id, forUserId: forUserId, name: memberName)),
      child: Container(
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: p.line3)) : null),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          PillIcon(color: routine.pillColor, shape: routine.pillShape, formName: routine.formName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(routine.medicineName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(second, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: AppType.small)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ]),
      ),
    );
  }
}
