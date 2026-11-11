import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/app_router.dart';
import '../../care/domain/care_models.dart';
import '../../care/domain/reading_rules.dart';
import '../../care/presentation/care_providers.dart';
import '../../care/presentation/care_widgets.dart';
import '../../care/presentation/condition_screen.dart';
import '../../care/presentation/reading_screen.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import '../../medicine_schedule/presentation/medicine_schedule_controller.dart';
import '../domain/health_models.dart';
import 'health_controller.dart';

/// The Health tab (Round 15, the demo's layout): My care (one row per
/// condition, add another), Targets and limits, "Measure and log" tiles with
/// the latest values, then Health records, health reminders, my reminders
/// and AI suggestions.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final s = strings.r15;
    final p = context.palette;
    final care = ref.watch(careOverviewProvider).valueOrNull ?? CareOverview.empty;
    final records = ref.watch(recordsOverviewProvider).valueOrNull ?? RecordsOverview.empty;
    final readings = ref.watch(healthRecordsProvider).valueOrNull ?? const <HealthRecordModel>[];
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    final today = ref.watch(todaysMedicineProvider).valueOrNull ?? const <MedicineDoseModel>[];
    final l = care.limits;
    final unit = care.limitsOrNone.sugarUnit;

    HealthRecordModel? last(String type) {
      for (final r in readings) {
        if (r.type == type) return r;
      }
      return null;
    }

    final bp = last('BLOOD_PRESSURE'), sugar = last('BLOOD_SUGAR'), weight = last('WEIGHT');
    final temp = last('TEMPERATURE'), sleep = last('SLEEP'), water = last('WATER');
    final done = today.where((d) => d.isTaken).length;
    final todayStart = dateOnly(DateTime.now());
    final insulinToday = readings.where((r) => r.type == 'INSULIN' && !r.recordedAt.toLocal().isBefore(todayStart)).length;

    Widget tracker(IconData icon, ToneKind tone, String title, String value, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon, tone: tone, size: 36),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(color: p.muted, fontSize: 13)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        );
    Widget row(IconData icon, ToneKind tone, String title, String? sub, VoidCallback onTap) => ListTile(
          leading: IconTile(icon, tone: tone),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    final limitsSummary = l != null && l.anySet
        ? [
            if (l.fastingLow != null && l.fastingHigh != null) '${s.tSugar} ${s.rangeFasting(sugarText(l.fastingLow!, unit), sugarText(l.fastingHigh!, unit))}',
            if (l.bpSystolicHigh != null && l.bpDiastolicHigh != null) '${s.tBp} ${s.rangeBp(l.bpSystolicHigh!, l.bpDiastolicHigh!)}',
          ].join(', ')
        : s.limitsNotSet;

    return Scaffold(
      appBar: AppBar(title: Text(strings.health)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          Text(s.healthSub, style: TextStyle(color: p.muted)),
          const SizedBox(height: 14),
          Text(s.myCare, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final code in care.conditions)
            CareConditionTile(code: code, name: conditionName(code, lookups, s.bn), summary: careSummary(code, care, records, readings, s, lookups)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push(myCarePath()),
              icon: const Icon(Icons.add),
              label: Text(care.conditions.isEmpty ? s.addCarePlan : s.addAnotherCarePlan),
            ),
          ),
          Card(
            child: ListTile(
              leading: const IconTile(Icons.track_changes, tone: ToneKind.ok),
              title: Text(s.targetsLimits, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(limitsSummary),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (l == null || !l.anySet) StateChip(s.set, tone: ToneKind.warn),
                const Icon(Icons.chevron_right),
              ]),
              onTap: () => context.push(limitsPath()),
            ),
          ),
          const SizedBox(height: 14),
          Text(s.measureAndLog, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              tracker(Icons.medication_outlined, ToneKind.navy, s.medicineTile, today.isEmpty ? '—' : '${s.n(done)}/${s.n(today.length)}', () => context.go(AppRoutes.medicinesTabPath('today'))),
              tracker(Icons.speed_outlined, ToneKind.navy, s.tBp, bp == null ? '—' : s.n(bp.value), () => context.push(readingPath('BLOOD_PRESSURE'))),
              tracker(Icons.water_drop_outlined, ToneKind.primary, s.tSugar,
                  sugar?.numericValue == null ? '—' : '${s.n(sugarText(sugar!.numericValue!, unit))} ${sugarUnitText(unit)}', () => context.push(readingPath('BLOOD_SUGAR'))),
              tracker(Icons.monitor_weight_outlined, ToneKind.navy, s.tWeight,
                  weight?.numericValue == null ? '—' : '${numText(weight!.numericValue!, s)} ${s.kg}${() {
                    final b = bmi(weight.numericValue!, care.heightCm);
                    return b == null ? '' : ', BMI ${s.n(b)}';
                  }()}', () => context.push(readingPath('WEIGHT'))),
              tracker(Icons.vaccines_outlined, ToneKind.navy, s.tInsulin, insulinToday == 0 ? s.addIfUsed : '${s.today}: ${s.n(insulinToday)}', () => context.push(insulinPath())),
              tracker(Icons.thermostat_outlined, ToneKind.warn, s.tTemp, temp == null ? '—' : '${s.n(temp.value)}°F', () => context.push(readingPath('TEMPERATURE'))),
              tracker(Icons.bedtime_outlined, ToneKind.ok, s.tSleep, sleep == null ? '—' : s.hoursValue(numText(sleep.numericValue ?? 0, s)), () => context.push(readingPath('SLEEP'))),
              tracker(Icons.local_drink_outlined, ToneKind.primary, s.tWater, water == null ? '—' : s.glasses(water.value), () => context.push(readingPath('WATER'))),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(children: [
              row(Icons.folder_outlined, ToneKind.navy, s.healthRecords, s.recordsSub, () => context.push(recordsPath())),
              row(Icons.monitor_heart_outlined, ToneKind.navy, s.allReadings, null, () => context.push(AppRoutes.healthReadings)),
              row(Icons.favorite_border, ToneKind.ok, strings.healthReminders, null, () => context.push(AppRoutes.healthReminders)),
              row(Icons.alarm_add_outlined, ToneKind.warn, strings.personalRemindersTitle, null, () => context.push(AppRoutes.personalReminders)),
              row(Icons.tips_and_updates_outlined, ToneKind.primary, strings.aiHealthSuggestions, null, () => context.push(AppRoutes.healthSuggestions)),
            ]),
          ),
        ],
      ),
    );
  }
}
