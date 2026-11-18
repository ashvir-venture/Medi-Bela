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
import '../../medicine_box/domain/medicine_box_models.dart';
import '../domain/medicine_schedule_models.dart';
import 'medicine_schedule_controller.dart';
import 'my_medicine_screen.dart' show AsNeededCard;
import 'my_medicines_screen.dart' show managedRoutinesProvider;
import 'routine_form_screen.dart';

final _packPhotoProvider = FutureProvider.autoDispose.family<String?, (String, String?)>((ref, key) async {
  final res = await ref.watch(dioClientProvider).dio.get<Map<String, dynamic>>(
        '/medicine-schedule/routines/${key.$1}/pack-photo',
        queryParameters: {'forUserId': ?key.$2},
      );
  return res.data?['url'] as String?;
});

final _boxProvider = FutureProvider.autoDispose.family<MedicineBox?, String?>((ref, forUserId) async {
  try {
    return await ref.watch(medicineBoxApiProvider).get(forUserId: forUserId);
  } catch (_) {
    return forUserId == null ? ref.watch(medicineBoxRepositoryProvider).cached() : null;
  }
});

/// Round 18 (client note point 6): one medicine's page, opened by tapping it
/// anywhere. What it is and how to take it, its pack photo, the box (count,
/// days left), today, the last 30 days; Edit and Remove at the very bottom
/// so nobody removes a medicine by mistake.
class MedicineDetailScreen extends ConsumerWidget {
  const MedicineDetailScreen({super.key, required this.routineId, this.forUserId, this.memberName});

  final String routineId;
  final String? forUserId;
  final String? memberName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final routines = ref.watch(managedRoutinesProvider(forUserId));
    return Scaffold(
      appBar: AppBar(title: Text(routines.valueOrNull?.where((r) => r.id == routineId).firstOrNull?.medicineName ?? strings.medicinesTab)),
      body: routines.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyErrorMessage(e), retryLabel: strings.retry, onRetry: () => ref.invalidate(managedRoutinesProvider(forUserId))),
        data: (list) {
          final r = list.where((x) => x.id == routineId).firstOrNull;
          if (r == null) return EmptyView(message: s.medicineNotFound, icon: Icons.medication_outlined);
          return _Body(routine: r, forUserId: forUserId, memberName: memberName);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.routine, this.forUserId, this.memberName});

  final ManagedRoutine routine;
  final String? forUserId;
  final String? memberName;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final changed = await context.push<bool>(AppRoutes.medicineForm, extra: RoutineFormArgs(forUserId: forUserId, routine: routine));
    if (changed == true) ref.invalidate(managedRoutinesProvider(forUserId));
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.removeMedicine),
        content: Text(strings.removeMedicineConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.palette.later, foregroundColor: ctx.palette.onLater),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.removeMedicine),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(medicineScheduleApiProvider).removeRoutine(routine.id, forUserId: forUserId);
      if (forUserId == null) await ref.read(refreshMedicineScheduleProvider)();
      ref.invalidate(managedRoutinesProvider(forUserId));
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r18;
    final p = context.palette;
    final r = routine;
    final month = forUserId == null ? (ref.watch(last30DaysDosesProvider).valueOrNull ?? const <MedicineDoseModel>[]) : const <MedicineDoseModel>[];
    final (x, y) = takenDays(r.id, month);
    final today = forUserId == null
        ? (ref.watch(dayDosesProvider(DateUtils.dateOnly(DateTime.now()))).valueOrNull ?? const <MedicineDoseModel>[]).where((d) => d.routineId == r.id).toList()
        : const <MedicineDoseModel>[];
    final photo = r.hasPackPhoto ? ref.watch(_packPhotoProvider((r.id, forUserId))).valueOrNull : null;
    final box = ref.watch(_boxProvider(forUserId)).valueOrNull?.item(r.id);

    String timesText() => r.scheduleTimes
        .map((t) => TimeOfDay(hour: int.parse(t.split(':')[0]), minute: int.parse(t.split(':')[1])).label(context))
        .join(', ');
    final how = r.asNeeded
        ? [s.asNeededTag, if (r.maxPerDay != null) s.upToPerDay(r.maxPerDay!)].join(', ')
        : r.weekdays.isNotEmpty
            ? s.onDays(r.weekdays.map((d) => s.weekdayShort[d]).join(', '))
            : r.intervalDays > 1
                ? s.everyNDays(r.intervalDays)
                : s.everyDayTimes(r.scheduleTimes.length);
    final rows = <(String, String)>[
      (s.howOften, how),
      if (!r.asNeeded && r.scheduleTimes.isNotEmpty) (s.whenRow, '${timesText()}${r.doseAmount == null ? '' : ' · ${r.doseAmount}'}'),
      if (r.mealTimingName != null) (s.foodRow, r.mealTimingName!),
      (s.howLongRow, r.durationDays == null ? s.ongoingTag : s.daysN(r.durationDays!)),
      if (r.note != null && r.note!.isNotEmpty) (s.noteRow, r.note!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              PillIcon(color: r.pillColor, shape: r.pillShape, formName: r.formName, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.medicineName, style: Theme.of(context).textTheme.titleLarge),
                  Text([r.formName, r.strength].whereType<String>().where((t) => t.isNotEmpty).join(', '),
                      style: TextStyle(color: p.muted, fontSize: AppType.small)),
                  if (!r.asNeeded && y > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(s.takenDaysOf(x, y), key: const ValueKey('detail-month'), style: TextStyle(color: p.onOkContainer, fontWeight: FontWeight.w700, fontSize: AppType.small)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: p.line3))),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 96, child: Text(rows[i].$1, style: TextStyle(color: p.muted, fontSize: AppType.small))),
                    Expanded(child: Text(rows[i].$2, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                ),
            ]),
          ),
        ),
        if (photo != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(photo, height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ],
        if (r.asNeeded) ...[
          const SizedBox(height: 12),
          AsNeededCard(routine: r, forUserId: forUserId),
        ],
        const SizedBox(height: 12),
        _BoxCard(item: box, strings: strings, forUserId: forUserId, memberName: memberName),
        if (today.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(s.todayTitle, style: Theme.of(context).textTheme.titleMedium),
                for (final d in today)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(child: Text(TimeOfDay.fromDateTime(d.scheduledAt).label(context))),
                      if (d.canMarkTakenAt(DateTime.now()))
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: p.taken, foregroundColor: p.onTaken),
                          onPressed: () => ref.read(markDoseTakenProvider)(d.id),
                          child: Text(strings.takenAction),
                        )
                      else
                        Icon(d.isTaken ? Icons.check_circle_rounded : Icons.schedule_rounded, color: d.isTaken ? p.taken : p.muted),
                    ]),
                  ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 28),
        // Client: change or remove only at the very bottom, so nobody does it by mistake.
        Text(s.removeAtBottomNote, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: AppType.small)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('detail-edit'),
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.edit_outlined),
          label: Text(strings.editMedicine),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('detail-remove'),
          style: OutlinedButton.styleFrom(foregroundColor: p.later, side: BorderSide(color: p.later)),
          onPressed: () => _remove(context, ref),
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(strings.removeMedicine),
        ),
      ],
    );
  }
}

class _BoxCard extends StatelessWidget {
  const _BoxCard({required this.item, required this.strings, this.forUserId, this.memberName});

  final MedicineBoxItem? item;
  final AppStrings strings;
  final String? forUserId;
  final String? memberName;

  @override
  Widget build(BuildContext context) {
    final s = strings.r18;
    final p = context.palette;
    final i = item;
    final unit = i?.unit ?? 'dose';
    final days = i?.daysLeftWith(0) ?? i?.daysLeft;
    final low = days != null && i != null && days < i.refillDays;
    return Card(
      color: low ? p.warnContainer : null,
      child: ListTile(
        key: const ValueKey('detail-box'),
        leading: Icon(Icons.inventory_2_outlined, color: low ? p.onWarnContainer : p.head),
        title: Text(strings.medicineBoxTitle),
        subtitle: Text(
          i == null || !i.counted
              ? s.notCounted
              : [s.inStock('${formatUnits(i.remainingWith(0) ?? 0)} ${s.unitName(unit)}'), if (days != null) s.daysLeftTag(days)].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.medicineBoxPath(forUserId: forUserId, name: memberName)),
      ),
    );
  }
}
