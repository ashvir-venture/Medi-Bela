import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../../medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../../medicine_schedule/presentation/my_medicines_screen.dart' show managedRoutinesProvider;
import '../domain/care_models.dart';
import 'care_blocks.dart';
import 'care_providers.dart';
import 'care_widgets.dart';

/// "For which condition" on Add / edit medicine (owner, 2026-11-12): a
/// label from the user's own conditions, shown on that condition's page.
/// Hidden when the user has picked no conditions.
class ConditionTagField extends ConsumerWidget {
  const ConditionTagField({super.key, required this.value, required this.onChanged, this.forUserId, this.enabled = true});

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? forUserId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final care = watchCareOf(ref, CareSubject(memberId: forUserId)).valueOrNull;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    final codes = care?.conditions ?? const <String>[];
    if (codes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.medicineForCondition + s.optional, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final code in codes)
            PillButton(
              label: conditionName(code, lookups, s.bn),
              selected: value == code,
              onTap: enabled ? () => onChanged(value == code ? null : code) : () {},
            ),
        ]),
        const SizedBox(height: 4),
        Text(s.medicineTagNote, style: TextStyle(color: p.muted, fontSize: 12)),
      ]),
    );
  }
}

/// "Medicines for this" on a condition page: the user's own medicines
/// tagged with it, each with "all doses on x of y days" and 7 dots (own
/// phone; a caregiver sees the list). Never a suggestion.
class MedicinesForBlock extends ConsumerWidget {
  const MedicinesForBlock(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final routines = ref.watch(managedRoutinesProvider(c.who.memberId)).valueOrNull;
    if (routines == null) return const SizedBox.shrink(); // offline: My medicines is online too
    final mine = routines.where((r) => r.conditionCode == c.code).toList();
    final week = c.who.isMember ? const <MedicineDoseModel>[] : (ref.watch(lastWeekDosesProvider).valueOrNull ?? const <MedicineDoseModel>[]);
    final now = DateTime.now();

    /// Per day (oldest first): 1 all taken, 0 any missed / not taken, null none.
    List<int?> dots(String routineId) => [
          for (var i = 6; i >= 0; i--)
            () {
              final day = dateOnly(now).subtract(Duration(days: i));
              final ds = week.where((d) => d.routineId == routineId && dateOnly(d.scheduledAt.toLocal()) == day && d.scheduledAt.isBefore(now)).toList();
              if (ds.isEmpty) return null;
              return ds.every((d) => d.isTaken) ? 1 : 0;
            }(),
        ];

    return SectionCard(
      title: s.medicinesForThis,
      trailing: TextButton(onPressed: () => context.go(Uri(path: '/medicines', queryParameters: {'tab': 'mine'}).toString()), child: Text(s.allMedicines)),
      children: [
        if (mine.isEmpty)
          Text(s.noMedsForThis, style: TextStyle(color: p.muted))
        else ...[
          if (!c.who.isMember) Text(s.takeRegularly, style: TextStyle(color: p.muted, fontSize: 13)),
          for (final r in mine)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const IconTile(Icons.medication_outlined, tone: ToneKind.navy, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.medicineName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      c.who.isMember
                          ? r.dosage
                          : () {
                              final d = dots(r.id);
                              final known = d.where((v) => v != null).length;
                              return known == 0 ? r.dosage : s.allDosesDays(d.where((v) => v == 1).length, known);
                            }(),
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                  ]),
                ),
                if (!c.who.isMember) SevenDots(dots(r.id)),
              ]),
            ),
        ],
      ],
    );
  }
}
