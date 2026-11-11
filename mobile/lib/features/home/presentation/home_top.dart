import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../notifications/notification_scheduler.dart';
import '../../../providers/core_providers.dart';
import '../../../router/app_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../family/presentation/family_controller.dart';
import '../../inbox/presentation/inbox_controller.dart';
import '../../medicine_schedule/domain/dose_display_status.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../../medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../../prescription/presentation/prescription_screen.dart';
import '../../reminders/presentation/reminder_status_controller.dart';
import '../domain/day_slots.dart';
import '../../../widgets/fit_label.dart';

/// Round 14, the demo's Home: a navy band (avatar → Profile, greeting and
/// name, EN | বাং, the bell), today's date and the reminder check, then the
/// "Today's medicine" card that overlaps the band.
class HomeBand extends ConsumerWidget {
  const HomeBand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final p = context.palette;
    final user = ref.watch(authControllerProvider).value;
    final isBangla = ref.watch(localeControllerProvider).languageCode == 'bn';
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final status = ref.watch(reminderStatusProvider).valueOrNull;
    final remindersOk = status != null && !status.blocked && !status.mayBeLate && status.batteryUnrestricted;
    final name = user?.name ?? strings.appName;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final now = DateTime.now();

    return Container(
      color: p.band,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: s.profileAndSettings,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push(AppRoutes.profile),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p.band2,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF5CC8D4), width: 2),
                    ),
                    child: Text(initial,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting(s, now), style: TextStyle(color: p.bandMuted, fontSize: 13)),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              OutlinedButton(
                key: const ValueKey('home-language'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: p.bandLine, width: 1.5),
                ),
                onPressed: () => ref.read(localeControllerProvider.notifier).setLanguage(isBangla ? 'en' : 'bn'),
                child: Text(isBangla ? 'EN' : 'বাং'),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: strings.notifications,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    await context.push(AppRoutes.inbox);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: p.band2, shape: BoxShape.circle),
                    child: Badge(
                      isLabelVisible: unread > 0,
                      backgroundColor: const Color(0xFFF2B266),
                      textColor: const Color(0xFF3A2610),
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(longDate(now, isBangla), style: TextStyle(color: p.bandMuted, fontSize: 14))),
              ActionChip(
                onPressed: () => context.push(AppRoutes.reminderCheck),
                backgroundColor: remindersOk ? p.band2 : const Color(0xFFF2B266),
                side: BorderSide.none,
                avatar: Icon(remindersOk ? Icons.circle : Icons.alarm,
                    size: remindersOk ? 10 : 16, color: remindersOk ? const Color(0xFF79C985) : const Color(0xFF3A2610)),
                label: Text(
                  remindersOk ? s.remindersWorking : s.fixReminders,
                  style: TextStyle(
                    color: remindersOk ? const Color(0xFFBDEBC4) : const Color(0xFF3A2610),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String greeting(Round14Strings s, DateTime now) {
  final h = now.hour;
  if (h < 12) return s.goodMorning;
  if (h < 15) return s.goodNoon;
  if (h < 18) return s.goodAfternoon;
  return s.goodEvening;
}

const _enDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _bnDays = ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'];
const _enMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _bnMonths = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];

/// "Tuesday, 10 November" / "মঙ্গলবার, ১০ নভেম্বর".
String longDate(DateTime d, bool bangla) => bangla
    ? '${_bnDays[d.weekday - 1]}, ${bnDigits('${d.day}')} ${_bnMonths[d.month - 1]}'
    : '${_enDays[d.weekday - 1]}, ${d.day} ${_enMonths[d.month - 1]}';

const _bnDigitChars = '০১২৩৪৫৬৭৮৯';

/// Western digits as Bengali digits (the demo writes numbers in Bangla).
String bnDigits(String s) => s.replaceAllMapped(RegExp('[0-9]'), (m) => _bnDigitChars[int.parse(m[0]!)]);

String _time(BuildContext context, DateTime t) => TimeOfDay.fromDateTime(t).format(context);

/// The "Today's medicine" card overlapping the band: x of y done, a bar with
/// one piece per dose, the time to act on with its medicines, Taken (green)
/// and Later (red), and the morning / afternoon / night strip.
class TodayHeroCard extends ConsumerWidget {
  const TodayHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final p = context.palette;
    final theme = Theme.of(context);
    final doses = ref.watch(todaysMedicineProvider).valueOrNull;
    final now = DateTime.now();

    Widget shell(List<Widget> children) => Transform.translate(
          offset: const Offset(0, -58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Material(
              color: p.surface,
              elevation: 3,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        );

    if (doses == null) return shell([Text(strings.todaysMedicine, style: theme.textTheme.titleLarge)]);

    if (doses.isEmpty) {
      return shell([
        Text(strings.todaysMedicine, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.medication_outlined, color: p.onPrimaryContainer, size: 32),
              const SizedBox(height: 8),
              Text(s.noMedicinesAdded, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(s.noMedicinesHelp, style: TextStyle(color: p.muted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => openPrescriptionEntryForm(context),
                icon: const Icon(Icons.photo_camera_outlined),
                label: FitLabel(Text(s.prescriptionShort)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => context.push(AppRoutes.medicineForm),
                icon: const Icon(Icons.add),
                label: FitLabel(Text(s.addMedicineShort)),
              ),
            ),
          ],
        ),
      ]);
    }

    final slots = daySlots(doses, now);
    final next = nextSlot(slots);
    final done = doses.where((d) => d.isTaken).length;

    Color segColor(MedicineDoseModel d) {
      if (d.isTaken) return p.success;
      if (d.status == 'MISSED' || d.status == 'SKIPPED') return p.warning;
      if (next != null && next.doses.contains(d) && next.state != SlotState.later) return theme.colorScheme.primary;
      return p.track;
    }

    return shell([
      Row(
        children: [
          Expanded(child: Text(strings.todaysMedicine, style: theme.textTheme.titleLarge)),
          TextButton(
            onPressed: () => context.go(AppRoutes.medicinesTabPath('today')),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(s.doneOf(done, doses.length)),
              const Icon(Icons.chevron_right, size: 20),
            ]),
          ),
        ],
      ),
      ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < doses.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: segColor(doses[i]), borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (next == null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.okContainer, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(Icons.check_circle, color: p.onOkContainer, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(s.allDoneToday,
                  style: TextStyle(color: p.onOkContainer, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ]),
        )
      else
        _NextSlot(view: next),
      const SizedBox(height: 12),
      Row(
        children: [
          for (final slot in slots)
            Expanded(child: _SlotStripItem(view: slot)),
        ],
      ),
    ]);
  }
}

String slotLabel(Round14Strings s, DaySlot slot) => switch (slot) {
      DaySlot.morning => s.morning,
      DaySlot.noon => s.noon,
      DaySlot.night => s.night,
    };

class _SlotStripItem extends ConsumerWidget {
  const _SlotStripItem({required this.view});

  final SlotView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r14;
    final p = context.palette;
    final (text, color, icon) = switch (view.state) {
      SlotState.done when view.missed > 0 => (s.missedCount(view.missed), Theme.of(context).colorScheme.error, Icons.alarm),
      SlotState.done => (s.statusDone, p.onOkContainer, Icons.check),
      SlotState.none => (s.statusNone, p.ink, null),
      SlotState.late => (s.statusLate, p.onWarnContainer, null),
      SlotState.now => (s.statusNow, p.link, null),
      SlotState.later => (s.dueCount(view.doses.length), p.ink, null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(slotLabel(s, view.slot), style: TextStyle(color: p.muted, fontSize: 13)),
        Row(children: [
          if (icon != null) Icon(icon, size: 18, color: color),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
      ],
    );
  }
}

class _NextSlot extends ConsumerWidget {
  const _NextSlot({required this.view});

  final SlotView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final p = context.palette;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final open = view.open;
    final due = view.state == SlotState.now || view.state == SlotState.late;
    final takeable = open.where((d) => d.canMarkTakenAt(now)).toList();
    final at = view.firstOpenAt;
    final stage = at == null ? 0 : currentStage(at, now);
    final laterAllowed = due && at != null && stage < maxReminderStage && now.isBefore(ReminderGroup(at, const []).lastRingAt);

    final chip = switch (view.state) {
      SlotState.now => (s.statusNow, p.warnContainer, p.onWarnContainer),
      SlotState.late => (s.statusLate, p.warnContainer, p.onWarnContainer),
      _ => (s.statusLater, p.navyContainer, p.onNavyContainer),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: p.link, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(at == null ? '' : _time(context, at), style: theme.textTheme.titleLarge)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: chip.$2, borderRadius: BorderRadius.circular(999)),
                child: Text(chip.$1, style: TextStyle(color: chip.$3, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          for (final d in open) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.medication, color: p.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.medicineName, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(d.dosage, style: TextStyle(color: p.muted, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (!due)
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.medicinesTabPath('today')),
              child: Text(s.seeFullDay),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    key: const ValueKey('home-taken'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: p.taken,
                      foregroundColor: p.onTaken,
                    ),
                    onPressed: takeable.isEmpty ? null : () => takeDoses(ref, takeable),
                    icon: const Icon(Icons.check, size: 24),
                    label: FitLabel(Text(strings.takenAction)),
                  ),
                ),
                if (laterAllowed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const ValueKey('home-later'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: p.later,
                        foregroundColor: p.onLater,
                      ),
                      onPressed: () => ref.read(notificationSchedulerProvider).snooze(at, stage),
                      child: FitLabel(Text(strings.reminderLaterAction)),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Marks [doses] taken (each inside its window), stops their reminders and
/// syncs, like the reminder page's Taken.
Future<void> takeDoses(WidgetRef ref, List<MedicineDoseModel> doses) async {
  final repo = ref.read(medicineScheduleRepositoryProvider);
  for (final d in doses) {
    await repo.markDoseTaken(d.id);
  }
  await ref.read(notificationSchedulerProvider).reconcileFromCache();
  await ref.read(syncServiceProvider).drainQueue();
}

/// A small chip for how a dose went: On time (green), Late (orange), Missed (red).
class DoseOutcomeChip extends ConsumerWidget {
  const DoseOutcomeChip({super.key, required this.outcome, this.given = false});

  final DoseOutcome outcome;
  final bool given;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r14;
    final p = context.palette;
    final (text, bg, fg, icon) = switch (outcome) {
      DoseOutcome.onTime => (s.outcomeOnTime, p.okContainer, p.onOkContainer, Icons.check),
      DoseOutcome.late => (s.outcomeLate, p.warnContainer, p.onWarnContainer, Icons.alarm),
      DoseOutcome.missed => (s.outcomeMissed, p.errorContainer, p.onErrorContainer, Icons.close),
    };
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        if (given)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: p.navyContainer, borderRadius: BorderRadius.circular(999)),
            child: Text(s.givenByCaregiver,
                style: TextStyle(color: p.onNavyContainer, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ],
    );
  }
}

/// Medicine box · Prescriptions · Notices · Health records (the demo's
/// services row; health videos come later).
class HomeServices extends ConsumerWidget {
  const HomeServices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final p = context.palette;
    Widget item(IconData icon, Color bg, Color fg, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: fg, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
                ],
              ),
            ),
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item(Icons.inventory_2_outlined, p.primaryContainer, p.onPrimaryContainer, strings.medicineBoxTitle,
                () => context.push(AppRoutes.medicineBox)),
            item(Icons.description_outlined, p.navyContainer, p.onNavyContainer, s.svcPrescriptions,
                () => context.go(AppRoutes.medicinesTabPath('prescriptions'))),
            item(Icons.campaign_outlined, p.warnContainer, p.onWarnContainer, s.svcNotices,
                () => context.push(AppRoutes.notices)),
            item(Icons.monitor_heart_outlined, p.okContainer, p.onOkContainer, s.svcRecords,
                () => context.go(AppRoutes.healthRecords)),
          ],
        ),
      ),
    );
  }
}

/// The family card: avatars and "Everyone is on track" / who missed one, or
/// "Add your family" when there is none. Online only (hidden when it can't load).
class HomeFamilyCard extends ConsumerWidget {
  const HomeFamilyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r14;
    final p = context.palette;
    final summary = ref.watch(familyStatusSummaryProvider).valueOrNull;
    if (summary == null) return const SizedBox.shrink();
    final members = summary.values.toList();
    final missed = members.where((m) => m.shared && m.missed > 0).toList();
    final title = members.isEmpty
        ? s.addFamilyTitle
        : missed.isNotEmpty
            ? s.familyDue(missed.first.name)
            : s.familyAllGood;
    final sub = members.isEmpty ? s.addFamilySub : s.familySee;
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: missed.isNotEmpty ? p.warnContainer : p.navyContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(members.isEmpty ? Icons.group_add_outlined : Icons.groups_outlined,
              color: missed.isNotEmpty ? p.onWarnContainer : p.onNavyContainer),
        ),
        title: Text(title),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.family),
      ),
    );
  }
}
