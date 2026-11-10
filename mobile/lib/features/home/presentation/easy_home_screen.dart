import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../family/domain/family_models.dart';
import '../../family/presentation/family_controller.dart';
import '../../help/presentation/help_screens.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../../medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../../reminders/presentation/reminder_status_controller.dart';
import '../domain/day_slots.dart';
import 'home_top.dart';

/// Round 14: easy mode for elders (the demo's easy home). Large text, today's
/// medicine with one big Taken, the morning / afternoon / night list, a call
/// button for each caregiver, and 999. Turned on in Settings, or by the
/// family's caregiver.
class EasyHomeScreen extends ConsumerWidget {
  const EasyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final doses = ref.watch(todaysMedicineProvider).valueOrNull ?? const <MedicineDoseModel>[];
    final members = ref.watch(familyMembersControllerProvider).valueOrNull ?? const <FamilyMemberModel>[];
    final carers = members.where((m) => m.role == 'CAREGIVER' && m.userId != user?.id).toList();
    final status = ref.watch(reminderStatusProvider).valueOrNull;
    final remindersOk = status == null || (!status.blocked && !status.mayBeLate && status.batteryUnrestricted);
    return Scaffold(
      body: EasyHomeBody(
        name: (user?.name ?? '').split(' ').first,
        doses: doses,
        carers: carers,
        remindersOk: remindersOk,
        onTake: (open) => takeDoses(ref, open),
      ),
    );
  }
}

/// What the easy home shows. [onTake] null = a preview (the caregiver's
/// "See what they see"): nothing can be tapped.
class EasyHomeBody extends ConsumerWidget {
  const EasyHomeBody({
    super.key,
    required this.name,
    required this.doses,
    this.carers = const [],
    this.remindersOk = true,
    this.onTake,
  });

  final String name;
  final List<MedicineDoseModel> doses;
  final List<FamilyMemberModel> carers;
  final bool remindersOk;
  final Future<void> Function(List<MedicineDoseModel>)? onTake;

  bool get _preview => onTake == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r14;
    final p = context.palette;
    final theme = Theme.of(context);
    final isBangla = ref.watch(localeControllerProvider).languageCode == 'bn';
    final now = DateTime.now();
    final slots = daySlots(doses, now);
    final next = nextSlot(slots);

    Widget card(Widget child, {Color? color, bool ring = false}) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color ?? p.surface,
            borderRadius: BorderRadius.circular(20),
            border: ring ? Border.all(color: theme.colorScheme.primary, width: 3) : null,
          ),
          child: child,
        );

    Widget doseCard() {
      if (doses.isEmpty) {
        return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.noMedicinesAdded, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(s.noMedicinesHelp, style: TextStyle(color: p.muted2, fontSize: 17)),
        ]));
      }
      if (next == null) {
        return card(
          Column(children: [
            Icon(Icons.check_circle, size: 72, color: p.onOkContainer),
            const SizedBox(height: 8),
            Text(s.allDoneToday,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: p.onOkContainer)),
          ]),
          color: p.okContainer,
        );
      }
      final due = next.state == SlotState.now || next.state == SlotState.late;
      final open = next.open;
      final takeable = open.where((d) => d.canMarkTakenAt(now)).toList();
      final at = next.firstOpenAt!;
      return card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              due ? (next.state == SlotState.late ? strings.doseDue : strings.reminderTitle) : s.easyNext(''),
              style: TextStyle(
                color: next.state == SlotState.late ? p.onWarnContainer : p.muted,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            Row(children: [
              Icon(Icons.schedule, size: 32, color: p.link),
              const SizedBox(width: 8),
              Text(TimeOfDay.fromDateTime(at).format(context),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: p.head)),
            ]),
            for (final d in open) ...[
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.medication, size: 34, color: p.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.medicineName, style: theme.textTheme.headlineSmall),
                    Text(d.dosage, style: TextStyle(color: p.muted2, fontSize: 17)),
                  ]),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            if (due)
              FilledButton.icon(
                key: const ValueKey('easy-taken'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(76),
                  backgroundColor: p.taken,
                  foregroundColor: p.onTaken,
                  textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _preview || takeable.isEmpty ? null : () => onTake!(takeable),
                icon: const Icon(Icons.check, size: 36),
                label: Text(s.easyTakeAll),
              ),
          ],
        ),
        ring: due,
      );
    }

    final list = [
      for (final slot in slots.where((v) => v.doses.isNotEmpty))
        () {
          final (text, color) = switch (slot.state) {
            SlotState.done when slot.missed > 0 => (s.missedCount(slot.missed), theme.colorScheme.error),
            SlotState.done => (s.easyTakeAll, p.onOkContainer),
            SlotState.late => (s.statusLate, p.onWarnContainer),
            SlotState.now => (s.statusNow, p.link),
            _ => (s.statusLater, p.muted),
          };
          return Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${slotLabel(s, slot.slot)}, ${TimeOfDay.fromDateTime(slot.doses.first.scheduledAt).format(context)}',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(slot.doses.map((d) => d.medicineName.split(' ').first).join(', '),
                      style: TextStyle(color: p.muted, fontSize: 15)),
                ]),
              ),
              Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 17)),
            ]),
          );
        }(),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: p.band,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting(s, now), style: TextStyle(color: p.bandMuted, fontSize: 17)),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                ]),
              ),
              if (!_preview) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(52, 44),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: p.bandLine, width: 1.5),
                  ),
                  onPressed: () => ref.read(localeControllerProvider.notifier).setLanguage(isBangla ? 'en' : 'bn'),
                  child: Text(isBangla ? 'EN' : 'বাং'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(52, 44),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: p.bandLine, width: 1.5),
                  ),
                  onPressed: () => context.push(AppRoutes.settings),
                  icon: const Icon(Icons.tune),
                  label: Text(strings.settings),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text(longDate(now, isBangla), style: TextStyle(color: p.bandMuted, fontSize: 17)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!remindersOk && !_preview)
                card(
                  InkWell(
                    onTap: () => context.push(AppRoutes.reminderCheck),
                    child: Row(children: [
                      const Icon(Icons.alarm, size: 30, color: Color(0xFF3A2610)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.fixReminders,
                            style: const TextStyle(color: Color(0xFF3A2610), fontSize: 19, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  color: const Color(0xFFF2B266),
                ),
              doseCard(),
              for (final c in carers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(76),
                      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _preview ? null : () => openExternal(context, ref, 'tel:${c.phone}', fallbackCopy: c.phone),
                    icon: const Icon(Icons.call, size: 30),
                    label: Text(s.easyCall(c.name.split(' ').first)),
                  ),
                ),
              card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(strings.todaysMedicine, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                if (list.isEmpty) Text(strings.noMedicineToday, style: TextStyle(color: p.muted, fontSize: 17)) else ...list,
              ])),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error, width: 1.5),
                ),
                onPressed: _preview ? null : () => openExternal(context, ref, 'tel:999', fallbackCopy: '999'),
                icon: const Icon(Icons.call),
                label: Text(s.easyEmergency),
              ),
              const SizedBox(height: 12),
              if (!_preview)
                Text(s.easyIsOn, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 14)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// The caregiver's "See what they see": a member's easy home, from their
/// shared doses today (names, times, status). Nothing can be tapped.
class EasyHomePreviewScreen extends ConsumerWidget {
  const EasyHomePreviewScreen({super.key, required this.name, required this.doses});

  final String name;
  final List<MedicineDoseModel> doses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider).r14;
    return Scaffold(
      appBar: AppBar(title: Text(s.easyPreview)),
      body: AbsorbPointer(child: EasyHomeBody(name: name.split(' ').first, doses: doses)),
    );
  }
}
