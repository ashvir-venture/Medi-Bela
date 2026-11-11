import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../health/domain/health_models.dart';
import '../../health/presentation/health_controller.dart';
import '../domain/care_models.dart';
import 'care_blocks.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import 'condition_heroes.dart';
import 'condition_screen.dart';
import 'reading_screen.dart';

/// Home's "My care" (Round 15 A): each picked condition gets a card with its
/// latest value; with none, "Have a long-term condition?" and Add a care plan.
class HomeCareCards extends ConsumerWidget {
  const HomeCareCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final care = ref.watch(careOverviewProvider).valueOrNull;
    if (care == null) return const SizedBox.shrink();
    final records = ref.watch(recordsOverviewProvider).valueOrNull ?? RecordsOverview.empty;
    final readings = ref.watch(healthRecordsProvider).valueOrNull ?? const <HealthRecordModel>[];
    final lookups = ref.watch(careLookupsProvider).valueOrNull;

    if (care.conditions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.favorite_outline, color: p.head),
                const SizedBox(width: 8),
                Expanded(child: Text(s.haveCondition, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              ]),
              const SizedBox(height: 4),
              Text(s.haveConditionSub, style: TextStyle(color: p.muted)),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: () => context.push(myCarePath()), child: Text(s.addCarePlan)),
            ]),
          ),
        ),
      );
    }

    HealthRecordModel? last(String type) {
      for (final r in readings) {
        if (r.type == type) return r;
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(s.myCare, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700))),
          TextButton.icon(onPressed: () => context.push(myCarePath()), icon: const Icon(Icons.tune, size: 18), label: Text(s.customize)),
        ]),
        for (final code in care.conditions)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(conditionPath(code)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    IconTile(conditionIcon(code)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(conditionName(code, lookups, s.bn), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(careSummary(code, care, records, readings, s, lookups), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                  if (code == 'diabetes' || code == 'bp') ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Builder(builder: (context) {
                        final ctx = CareCtx(code: code, care: care, records: records, readings: readings, lookups: lookups, who: const CareSubject(), s: s);
                        final chip = code == 'bp' ? bpChipFor(last('BLOOD_PRESSURE'), ctx) : sugarChipFor(last('BLOOD_SUGAR'), ctx);
                        return chip ?? const SizedBox.shrink();
                      }),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () => context.push(readingPath(code == 'bp' ? 'BLOOD_PRESSURE' : 'BLOOD_SUGAR')),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(code == 'bp' ? s.logBp : s.logSugar),
                      ),
                    ]),
                  ],
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
