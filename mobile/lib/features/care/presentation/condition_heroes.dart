import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../health/domain/health_models.dart';
import '../domain/care_content.dart';
import '../domain/care_models.dart';
import '../domain/reading_rules.dart';
import 'care_actions.dart';
import 'care_blocks.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import 'reading_screen.dart';

int _avg(Iterable<int> xs) => xs.isEmpty ? 0 : (xs.reduce((a, b) => a + b) / xs.length).round();

List<String> _lastDaysLabels(int days, Round15Strings s) {
  final today = dateOnly(DateTime.now());
  return [
    shortDate(today.subtract(Duration(days: days - 1)), s),
    shortDate(today.subtract(Duration(days: days ~/ 2)), s),
    s.today,
  ];
}

/// The last value per day for [days] days (oldest first), from [rs].
List<double?> dailySeries(List<HealthRecordModel> rs, int days, double? Function(HealthRecordModel r) pick) {
  final today = dateOnly(DateTime.now());
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final day = today.subtract(Duration(days: i));
        for (final r in rs) {
          if (dateOnly(r.recordedAt.toLocal()) == day) return pick(r);
        }
        return null;
      }(),
  ];
}

Widget? bpChipFor(HealthRecordModel? r, CareCtx c) {
  if (r == null || r.systolic == null || r.diastolic == null) return null;
  final s = c.s;
  if (isBpCrisis(r.systolic!, r.diastolic!, c.care.limits, pregnant: c.care.has('pregnancy'))) {
    return StateChip(s.veryHigh, tone: ToneKind.error, icon: Icons.warning_amber_rounded);
  }
  return rangeChip(bpRange(r.systolic!, r.diastolic!, c.care.limits), inRange: s.inRange, above: s.aboveRange, below: s.belowRange);
}

Widget? sugarChipFor(HealthRecordModel? r, CareCtx c) {
  final v = r?.numericValue;
  if (r == null || v == null) return null;
  final s = c.s;
  if (isSugarCrisis(v)) return StateChip(s.veryLow, tone: ToneKind.error, icon: Icons.warning_amber_rounded);
  return rangeChip(sugarRange(v, r.sugarContext, c.care.limits), inRange: s.inRange, above: s.aboveRange, below: s.belowRange);
}

// --- Diabetes -----------------------------------------------------------------

class DiabetesSugarHero extends StatelessWidget {
  const DiabetesSugarHero(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final p = context.palette;
    final l = c.care.limits;
    final unit = c.care.limitsOrNone.sugarUnit;
    final fasting = c.of('BLOOD_SUGAR').where((r) => r.sugarContext == 'FASTING').toList();
    final series = dailySeries(fasting, 7, (r) => r.numericValue == null ? null : fromMmol(r.numericValue!, unit));
    final hasAny = series.any((v) => v != null);
    final rows = <(String, String)>[
      if (l?.fastingLow != null || l?.fastingHigh != null)
        (tr(sugarContextNames['FASTING']!, s.bn), '${l?.fastingLow == null ? '—' : s.n(sugarText(l!.fastingLow!, unit))}–${l?.fastingHigh == null ? '—' : s.n(sugarText(l!.fastingHigh!, unit))}'),
      if (l?.afterFoodHigh != null) (s.limAfterHi, s.n(sugarText(l!.afterFoodHigh!, unit))),
      if (l?.lowSugar != null) (s.limLow, s.n(sugarText(l!.lowSugar!, unit))),
      if (l?.hba1cTarget != null) (s.limHba1c, '${numText(l!.hba1cTarget!, s)}%'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        title: s.fastingSeven,
        trailing: l?.fastingLow != null && l?.fastingHigh != null
            ? Text(s.rangeFasting(sugarText(l!.fastingLow!, unit), sugarText(l.fastingHigh!, unit)), style: TextStyle(color: p.muted, fontSize: 13))
            : null,
        children: [
          if (hasAny)
            SparkChart(
              values: series,
              low: l?.fastingLow == null ? null : fromMmol(l!.fastingLow!, unit),
              high: l?.fastingHigh == null ? null : fromMmol(l!.fastingHigh!, unit),
              labels: _lastDaysLabels(7, s),
            )
          else
            Text(s.noSugarYet, style: TextStyle(color: p.muted)),
          const SizedBox(height: 8),
          NoteLine(s.chartNote),
        ],
      ),
      SectionCard(
        title: s.yourLimits,
        trailing: TextButton.icon(onPressed: () => context.push(limitsPath(c.who)), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(s.change)),
        children: [
          if (rows.isEmpty) Text(s.noLimitYet, style: TextStyle(color: p.muted)),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [Expanded(child: Text(k)), Text(v, style: const TextStyle(fontWeight: FontWeight.w700))]),
            ),
          if (rows.isNotEmpty) Text('${sugarUnitText(unit)}${l?.doctorNote == null ? '' : ' · ${s.setBy(l!.doctorNote!)}'}', style: TextStyle(color: p.muted, fontSize: 12)),
        ],
      ),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => context.push(readingPath('BLOOD_SUGAR', c.who)), icon: const Icon(Icons.add), label: Text(s.logSugar))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/health/records/pdf'), icon: const Icon(Icons.description_outlined), label: Text(s.doctorPdf))),
      ]),
    ]);
  }
}

// --- Blood pressure ------------------------------------------------------------

class BpHero extends StatelessWidget {
  const BpHero(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final p = context.palette;
    final all = c.of('BLOOD_PRESSURE').where((r) => r.systolic != null && r.diastolic != null).toList();
    final last = all.isEmpty ? null : all.first;
    final now = DateTime.now();
    final week = all.where((r) => now.difference(r.recordedAt).inDays < 7).toList();
    final am = week.where((r) => r.recordedAt.toLocal().hour < 12).toList();
    final pm = week.where((r) => r.recordedAt.toLocal().hour >= 12).toList();
    final two = all.where((r) => now.difference(r.recordedAt).inDays < 14).toList();
    final judged = two.map((r) => bpRange(r.systolic!, r.diastolic!, c.care.limits)).where((x) => x != null).toList();
    final inRange = judged.where((x) => x == RangeState.inRange).length;
    final today = dateOnly(now);
    final todayAm = all.any((r) => dateOnly(r.recordedAt.toLocal()) == today && r.recordedAt.toLocal().hour < 12);
    final todayPm = all.any((r) => dateOnly(r.recordedAt.toLocal()) == today && r.recordedAt.toLocal().hour >= 12);
    final pulses = week.map((r) => r.pulse).whereType<int>().toList();
    String avg(List<HealthRecordModel> xs) => xs.isEmpty ? '—' : s.n('${_avg(xs.map((r) => r.systolic!))}/${_avg(xs.map((r) => r.diastolic!))}');
    final l = c.care.limits;
    final chip = bpChipFor(last, c);

    Widget session(String label, bool done) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: done ? p.okContainer : p.surface2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(done ? Icons.check : Icons.schedule, size: 18, color: done ? p.onOkContainer : p.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(done ? label : '$label · ${s.due}', style: TextStyle(color: done ? p.onOkContainer : p.ink, fontSize: 13))),
            ]),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(children: [
        Text(s.lastReading, style: TextStyle(color: p.muted, fontSize: 13)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(last == null ? '—' : s.n('${last.systolic}/${last.diastolic}'), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: p.head)),
          const SizedBox(width: 6),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('mmHg')),
          const Spacer(),
          ?chip,
        ]),
        if (last != null)
          Text('${dayLabel(last.recordedAt, s)}, ${timeLabel(context, last.recordedAt.toLocal(), s)}${last.pulse == null ? '' : ', ${s.pulse} ${s.n(last.pulse!)}'}',
              style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 10),
        StatRow([
          StatBox(label: s.morningAvg, value: avg(am), sub: s.sevenDays),
          StatBox(label: s.eveningAvg, value: avg(pm), sub: s.sevenDays),
          StatBox(label: s.inRange, value: judged.isEmpty ? '—' : '${s.n(inRange)}/${s.n(judged.length)}', sub: s.readings14),
        ]),
        const SizedBox(height: 10),
        Text(s.measureTwiceToday, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [session(s.morningBeforeMed, todayAm), const SizedBox(width: 8), session(s.evening, todayPm)]),
        const SizedBox(height: 12),
        if (two.isNotEmpty)
          SparkChart(
            values: dailySeries(two, 14, (r) => r.systolic?.toDouble()),
            second: dailySeries(two, 14, (r) => r.diastolic?.toDouble()),
            high: l?.bpSystolicHigh?.toDouble(),
            labels: _lastDaysLabels(14, s),
          ),
        if (pulses.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${s.pulse}: ${s.n(_avg(pulses))}/min (${s.sevenDays})', style: TextStyle(color: p.muted, fontSize: 13)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => context.push(readingPath('BLOOD_PRESSURE', c.who)), icon: const Icon(Icons.add), label: Text(s.logBp))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => context.push(limitsPath(c.who)), icon: const Icon(Icons.track_changes, size: 18), label: Text(s.change))),
        ]),
      ]),
    ]);
  }
}

// --- Pregnancy -------------------------------------------------------------------

class PregnancyHero extends ConsumerWidget {
  const PregnancyHero(this.c, {super.key});

  final CareCtx c;

  Future<void> _pickDue(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final current = c.setting['dueDate'] is String ? parseDate(c.setting['dueDate'] as String) : now.add(const Duration(days: 180));
    final d = await showDatePicker(context: context, initialDate: current, firstDate: now.subtract(const Duration(days: 30)), lastDate: now.add(const Duration(days: 300)));
    if (d == null || !context.mounted) return;
    await runCareAction(context, ref, () => CareActions(ref, c.who).updateSetting('pregnancy', {'dueDate': isoDate(d)}));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final due = c.setting['dueDate'] is String ? parseDate(c.setting['dueDate'] as String) : null;
    final g = gestation(due, DateTime.now());
    if (g == null || due == null) {
      return SectionCard(title: s.addDueDate, subtitle: s.addDueDateSub, children: [
        FilledButton.icon(onPressed: () => _pickDue(context, ref), icon: const Icon(Icons.event), label: Text(s.dueDate)),
      ]);
    }
    return Card(
      color: p.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.pregnancy, style: TextStyle(color: p.onPrimaryContainer, fontSize: 13)),
                Text(s.weeksDays(g.weeks, g.days), style: TextStyle(color: p.onPrimaryContainer, fontSize: 28, fontWeight: FontWeight.w800)),
                Text(s.trimester(g.trimester), style: TextStyle(color: p.muted2)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(s.dueDate, style: TextStyle(color: p.muted, fontSize: 13)),
              Text(shortDate(due, s), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s.weeksToGo(g.weeksLeft), style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: (g.weeks * 7 + g.days) / 280, minHeight: 10, backgroundColor: p.surface),
          ),
          TextButton.icon(onPressed: () => _pickDue(context, ref), icon: const Icon(Icons.edit_calendar_outlined, size: 18), label: Text(s.changeDueDate)),
        ]),
      ),
    );
  }
}

/// Pregnancy check-ups: numbered ANC appointments, mark done, add another.
class AncBlock extends ConsumerWidget {
  const AncBlock(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final anc = c.records.appointments.where((a) => a.kind == AppointmentKind.anc).toList()..sort((a, b) => a.date.compareTo(b.date));
    final done = anc.where((a) => a.done).length;
    final next = anc.where((a) => !a.done).firstOrNull;
    return SectionCard(
      title: s.ancTitle,
      trailing: Text(s.doneOf(done, anc.length), style: TextStyle(color: p.onOkContainer, fontWeight: FontWeight.w700)),
      children: [
        for (var i = 0; i < anc.length; i++)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: anc[i].done ? p.okContainer : p.navyContainer,
                child: anc[i].done ? Icon(Icons.check, color: p.onOkContainer) : Text(s.n(anc[i].number ?? i + 1), style: TextStyle(color: p.onNavyContainer, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => context.push(visitFormPath(id: anc[i].id, kind: 'ANC', condition: 'pregnancy', who: c.who)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.checkupN(anc[i].number ?? i + 1), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${shortDate(anc[i].day, s)}${anc[i].done ? '' : ', ${inDaysLabel(anc[i].day, s)}'}', style: TextStyle(color: p.muted, fontSize: 13)),
                  ]),
                ),
              ),
              if (anc[i].done)
                StateChip(s.done, tone: ToneKind.ok, icon: Icons.check)
              else if (anc[i] == next)
                OutlinedButton(
                  style: compactOutlined,
                  onPressed: () => runCareAction(context, ref, () => CareActions(ref, c.who).saveAppointment({'done': true}, id: anc[i].id)),
                  child: Text(s.markDone),
                ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push(visitFormPath(kind: 'ANC', condition: 'pregnancy', who: c.who)),
            icon: const Icon(Icons.add),
            label: Text(s.addCheckup),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.checkedEachVisit, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(tr(ancChecked, s.bn), style: TextStyle(color: p.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 6),
        Text(tr(ancGuideline, s.bn), style: TextStyle(color: p.muted, fontSize: 12)),
      ],
    );
  }
}

/// Baby's movements: from 28 weeks, tap per movement, then save (KICKS log).
class KicksBlock extends ConsumerStatefulWidget {
  const KicksBlock(this.c, {super.key});

  final CareCtx c;

  @override
  ConsumerState<KicksBlock> createState() => _KicksBlockState();
}

class _KicksBlockState extends ConsumerState<KicksBlock> {
  DateTime? _started;
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.s;
    final p = context.palette;
    final due = c.setting['dueDate'] is String ? parseDate(c.setting['dueDate'] as String) : null;
    final g = gestation(due, DateTime.now());
    if (g == null) return const SizedBox.shrink();
    if (g.weeks < 28) {
      return SectionCard(children: [
        Row(children: [
          const IconTile(Icons.favorite_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.countingMovements, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s.kicksFrom28(28 - g.weeks), style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
        ]),
      ]);
    }
    final recent = c.care.logs.where((l) => l.kind == CareLogKind.kicks).take(3).toList();
    return SectionCard(
      title: s.kicksTitle,
      trailing: recent.isEmpty ? null : Text(s.lastOn(dayLabel(recent.first.loggedAt, s)), style: TextStyle(color: p.muted, fontSize: 13)),
      children: [
        if (_started != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2)),
            child: Text('${s.n(_count)} ${s.times}', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: p.head)),
          ),
          const SizedBox(height: 6),
          Text(s.kicksStarted(timeLabel(context, _started!, s)), textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.taken, foregroundColor: p.onTaken, minimumSize: const Size.fromHeight(64)),
            onPressed: () => setState(() => _count++),
            icon: const Icon(Icons.favorite),
            label: Text(s.babyMoved, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final minutes = DateTime.now().difference(_started!).inMinutes.clamp(0, 240);
              final ok = await runCareAction(context, ref, () => CareActions(ref, c.who).addLog(CareLogKind.kicks, {'count': _count.clamp(0, 200), 'minutes': minutes}, condition: 'pregnancy'), done: s.saved);
              if (ok && mounted) {
                setState(() {
                  _started = null;
                  _count = 0;
                });
              }
            },
            child: Text(s.finishSave),
          ),
        ] else
          FilledButton.icon(onPressed: () => setState(() => _started = DateTime.now()), icon: const Icon(Icons.play_arrow), label: Text(s.startCounting)),
        for (final k in recent)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: Text('${dayLabel(k.loggedAt, s)}, ${timeLabel(context, k.loggedAt, s)}', style: TextStyle(color: p.muted))),
              Text(s.kicksIn(k.count, k.minutes), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        const SizedBox(height: 8),
        NoteLine(tr(kickNote, s.bn)),
      ],
    );
  }
}

class PregnancyVitalsBlock extends ConsumerWidget {
  const PregnancyVitalsBlock(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final b = c.last('BLOOD_PRESSURE');
    final w = c.last('WEIGHT');
    final start = (c.setting['startWeightKg'] as num?)?.toDouble();
    final gain = w?.numericValue == null || start == null ? null : w!.numericValue! - start;
    return SectionCard(title: s.bpAndWeight, children: [
      StatRow([
        StatBox(label: s.lastBp, value: b?.systolic == null ? '—' : s.n('${b!.systolic}/${b.diastolic}'), sub: b == null ? null : dayLabel(b.recordedAt, s)),
        StatBox(
          label: s.tWeight,
          value: w?.numericValue == null ? '—' : '${numText(w!.numericValue!, s)} ${s.kg}',
          sub: gain == null ? null : s.sinceStart('${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}'),
        ),
      ]),
      if (start == null)
        TextButton(
          onPressed: () async {
            final controller = TextEditingController();
            final kg = await showDialog<double>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(s.startWeight),
                content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
                  FilledButton(onPressed: () => Navigator.pop(ctx, parseNumber(controller.text)), child: Text(s.save)),
                ],
              ),
            );
            if (kg == null || kg < 20 || kg > 200 || !context.mounted) return;
            await runCareAction(context, ref, () => CareActions(ref, c.who).updateSetting('pregnancy', {'startWeightKg': kg}));
          },
          child: Text(s.startWeight),
        ),
      const SizedBox(height: 6),
      Text(tr(pregnancyBpNote, s.bn), style: TextStyle(color: p.muted, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: FilledButton(onPressed: () => context.push(readingPath('BLOOD_PRESSURE', c.who)), child: Text(s.logBp))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () => context.push(readingPath('WEIGHT', c.who)), child: Text(s.logWeight))),
      ]),
    ]);
  }
}

class TdBlock extends ConsumerWidget {
  const TdBlock(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final doses = c.care.logs.where((l) => l.kind == CareLogKind.tdDose && l.date != null).toList()..sort((a, b) => a.date!.compareTo(b.date!));
    final text = doses.isEmpty ? s.tdNone : s.tdDoses(doses.length, shortDate(parseDate(doses.last.date!), s));
    return SectionCard(children: [
      Row(children: [
        const IconTile(Icons.vaccines_outlined, tone: ToneKind.navy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.tdVaccine, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('$text. ${tr(tdNote, s.bn)}', style: TextStyle(color: p.muted, fontSize: 13)),
          ]),
        ),
        OutlinedButton(
          style: compactOutlined,
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, initialDate: now, firstDate: now.subtract(const Duration(days: 700)), lastDate: now);
            if (d == null || !context.mounted) return;
            await runCareAction(context, ref, () => CareActions(ref, c.who).addLog(CareLogKind.tdDose, {'date': isoDate(d)}, condition: 'pregnancy'));
          },
          child: Text(s.addDose),
        ),
      ]),
    ]);
  }
}

class BirthPlanBlock extends ConsumerStatefulWidget {
  const BirthPlanBlock(this.c, {super.key});

  final CareCtx c;

  @override
  ConsumerState<BirthPlanBlock> createState() => _BirthPlanBlockState();
}

class _BirthPlanBlockState extends ConsumerState<BirthPlanBlock> {
  bool _open = false;
  Map<String, TextEditingController>? _fields;
  bool _money = false;

  static const _keys = ['hospital', 'transport', 'bloodGroup', 'donor', 'companion'];

  @override
  void dispose() {
    for (final c in _fields?.values ?? const <TextEditingController>[]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.s;
    final p = context.palette;
    final plan = Map<String, dynamic>.from(c.setting['birthPlan'] as Map? ?? {});
    _fields ??= {for (final k in _keys) k: TextEditingController(text: plan[k] as String? ?? '')};
    if (!_open) _money = plan['moneySetAside'] == true;
    final ready = _keys.where((k) => (plan[k] as String? ?? '').trim().isNotEmpty).length + (plan['moneySetAside'] == true ? 1 : 0);
    final labels = {
      'hospital': (s.bpHospital, s.bpHospitalHint),
      'transport': (s.bpTransport, s.bpTransportHint),
      'bloodGroup': (s.bpBlood, 'B+'),
      'donor': (s.bpDonor, s.bpDonorHint),
      'companion': (s.bpCompanion, s.bpName),
    };
    return SectionCard(children: [
      InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Row(children: [
          const IconTile(Icons.checklist, tone: ToneKind.ok, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.birthPlan, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(s.birthPlanReady(ready), style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
          Icon(_open ? Icons.expand_less : Icons.expand_more),
        ]),
      ),
      if (_open) ...[
        const SizedBox(height: 8),
        for (final k in _keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: _fields![k], decoration: InputDecoration(labelText: labels[k]!.$1, hintText: labels[k]!.$2)),
          ),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _money, onChanged: (v) => setState(() => _money = v), title: Text(s.bpMoney)),
        Text(tr(birthPlanNote, s.bn), style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => runCareAction(
            context,
            ref,
            () => CareActions(ref, c.who).updateSetting('pregnancy', {
              'birthPlan': {for (final k in _keys) k: _fields![k]!.text.trim(), 'moneySetAside': _money},
            }),
            done: s.saved,
          ),
          child: Text(s.save),
        ),
      ],
    ]);
  }
}

// --- Heart ---------------------------------------------------------------------

class HeartHero extends StatelessWidget {
  const HeartHero(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final p = context.palette;
    final weights = [for (final r in c.of('WEIGHT')) if (r.numericValue != null) (r.recordedAt.toLocal(), r.numericValue!)];
    final last = c.last('WEIGHT');
    final gain = weightGain3Days(weights);
    final limit = c.care.limits?.weightGain3Days;
    final warn = gain != null && limit != null && gain >= limit;
    final b = c.last('BLOOD_PRESSURE');
    return SectionCard(children: [
      StatRow([
        StatBox(label: s.weightToday, value: last?.numericValue == null ? '—' : '${numText(last!.numericValue!, s)} ${s.kg}', sub: last == null ? null : dayLabel(last.recordedAt, s)),
        StatBox(label: s.in3Days, value: gain == null ? '—' : s.n('${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}'), sub: s.kg),
        StatBox(label: s.bpPulse, value: b?.systolic == null ? '—' : s.n('${b!.systolic}/${b.diastolic}'), sub: b?.pulse == null ? null : '${s.pulse} ${s.n(b!.pulse!)}'),
      ]),
      const SizedBox(height: 10),
      if (warn)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.warnContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: p.onWarnContainer),
            const SizedBox(width: 8),
            Expanded(child: Text(s.weightRose(gain.toStringAsFixed(1), numText(limit, s)), style: TextStyle(color: p.onWarnContainer))),
          ]),
        )
      else
        Text(limit == null ? s.weightNoLimit : s.weightAlertNote(numText(limit, s)), style: TextStyle(color: p.muted, fontSize: 13)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton(onPressed: () => context.push(readingPath('WEIGHT', c.who)), child: Text(s.logWeight))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () => context.push(readingPath('BLOOD_PRESSURE', c.who)), child: Text(s.bpAndPulse))),
      ]),
    ]);
  }
}

// --- Kidney ----------------------------------------------------------------------

/// The trend of one lab value (test kind + field code) from test results.
List<(String, double)> labPoints(CareCtx c, String kind, String field) {
  final k = c.lookups?.testKind(kind);
  final f = k?.fields.where((x) => x.code == field).firstOrNull;
  if (f == null) return const [];
  return [
    for (final t in c.records.resultsOf(kind))
      if (t.valueOf(f.id) != null) (shortDate(t.day, c.s), t.valueOf(f.id)!),
  ];
}

class KidneyHero extends ConsumerWidget {
  const KidneyHero(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final pts = labPoints(c, 'kidney', 'creat');
    final results = c.records.resultsOf('kidney');
    final b = c.last('BLOOD_PRESSURE');
    final l = c.care.limits;
    final k = c.setting;
    final dialysis = k['dialysis'] == true;
    final days = [for (final d in (k['dialysisDays'] as List? ?? [])) (d as num).toInt()];
    final time = k['dialysisTime'] as String?;
    Future<void> save(Map<String, dynamic> m) => runCareAction(context, ref, () => CareActions(ref, c.who).updateSetting('kidney', m));
    return SectionCard(
      title: s.creatinineResults,
      trailing: results.isEmpty ? null : Text(s.lastResult(shortDate(results.last.day, s)), style: TextStyle(color: p.muted, fontSize: 13)),
      children: [
        TrendBars(points: pts, empty: s.noResults, unit: 'mg/dL'),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.push(testFormPath(kind: 'kidney', done: true, condition: 'kidney', who: c.who)),
            icon: const Icon(Icons.add),
            label: Text(s.addResult),
          ),
        ),
        const SizedBox(height: 8),
        StatRow([
          StatBox(label: s.lastBp, value: b?.systolic == null ? '—' : s.n('${b!.systolic}/${b.diastolic}')),
          StatBox(label: s.fluidLimit, value: l?.fluidLimitMl == null || l!.fluidLimitMl == 0 ? s.notSet : '${s.n(l.fluidLimitMl!)} ${s.ml}'),
        ]),
        const Divider(height: 20),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: dialysis,
          onChanged: (v) => save({'dialysis': v}),
          title: Text(s.onDialysis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(dialysis && days.isNotEmpty ? s.dialysisDays([for (final d in days..sort()) s.weekdaysShort[d]].join(', ')) : s.dialysisOff),
        ),
        if (dialysis) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var d = 0; d < 7; d++)
              PillButton(
                label: s.weekdaysShort[d],
                selected: days.contains(d),
                onTap: () => save({'dialysisDays': days.contains(d) ? (days..remove(d)) : [...days, d]}),
              ),
          ]),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.sessionTime),
            trailing: Text(time == null ? '—' : hhmmLabel(context, time, s), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () async {
              final parts = (time ?? '09:00').split(':').map(int.parse).toList();
              final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: parts[0], minute: parts[1]));
              if (t == null) return;
              await save({'dialysisTime': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'});
            },
          ),
        ],
      ],
    );
  }
}

// --- Asthma ----------------------------------------------------------------------

class AsthmaHero extends ConsumerWidget {
  const AsthmaHero(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final now = DateTime.now();
    final days = relieverDays(c.care.logs, now);
    final nights = sevenDayDots((d) => c.care.ticked('asthma_night', d), now).where((v) => v == 1).length;
    final pf = c.last('PEAK_FLOW');
    final best = c.care.limits?.peakFlowBest;
    final zone = pf?.numericValue == null ? null : peakFlowZone(pf!.numericValue!, best);
    final triggers = [for (final t in (c.setting['triggers'] as List? ?? [])) t as String];
    final lastNight = dateOnly(now);
    return SectionCard(children: [
      StatRow([
        StatBox(label: s.reliever, value: s.daysCount(days), sub: s.thisWeek),
        StatBox(label: s.nightWaking, value: s.nightsCount(nights), sub: s.thisWeek),
        StatBox(label: s.peakFlow, value: pf?.numericValue == null ? '—' : numText(pf!.numericValue!, s), sub: zone == null ? null : s.ofBest(zone.percent)),
      ]),
      const SizedBox(height: 10),
      if (days > 2)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.warnContainer, borderRadius: BorderRadius.circular(12)),
          child: Text(s.relieverWarn, style: TextStyle(color: p.onWarnContainer)),
        )
      else
        Text(s.relieverNote, style: TextStyle(color: p.muted, fontSize: 13)),
      if (zone != null) ...[
        const SizedBox(height: 8),
        Row(children: [
          StateChip(
            switch (zone.zone) { PeakFlowZone.green => s.greenZone, PeakFlowZone.yellow => s.yellowZone, PeakFlowZone.red => s.redZone },
            tone: switch (zone.zone) { PeakFlowZone.green => ToneKind.ok, PeakFlowZone.yellow => ToneKind.warn, PeakFlowZone.red => ToneKind.error },
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(s.basedOnBest(best!), style: TextStyle(color: p.muted, fontSize: 13))),
        ]),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => runCareAction(context, ref, () => CareActions(ref, c.who).addLog(CareLogKind.reliever, {'puffs': 1}, condition: 'asthma'), done: s.relieverLogged),
            icon: const Icon(Icons.air),
            label: Text(s.usedReliever),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(onPressed: () => context.push(readingPath('PEAK_FLOW', c.who)), child: Text(s.logPeakFlow))),
      ]),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: c.care.ticked('asthma_night', lastNight),
        onChanged: (v) => runCareAction(context, ref, () => CareActions(ref, c.who).setTick('asthma_night', lastNight, v ?? false)),
        title: Text(s.wokeLastNight),
      ),
      const Divider(),
      Text(s.myTriggers, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in asthmaTriggers.entries)
          PillButton(
            label: tr(e.value, s.bn),
            selected: triggers.contains(e.key),
            onTap: () => runCareAction(
              context,
              ref,
              () => CareActions(ref, c.who).updateSetting('asthma', {
                'triggers': triggers.contains(e.key) ? ([...triggers]..remove(e.key)) : [...triggers, e.key],
              }),
            ),
          ),
      ]),
    ]);
  }
}

// --- Thyroid ---------------------------------------------------------------------

class ThyroidHero extends StatelessWidget {
  const ThyroidHero(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context) {
    final s = c.s;
    final p = context.palette;
    final pts = labPoints(c, 'tsh', 'tsh');
    final next = c.records.upcomingTests.where((t) => t.testKindCode == 'tsh').firstOrNull;
    final l = c.care.limits;
    final chip = pts.isEmpty
        ? null
        : rangeChip(tshRange(pts.last.$2, l), inRange: s.inRange, above: s.aboveRange, below: s.belowRange);
    return SectionCard(
      title: s.tshResults,
      trailing: next != null
          ? StateChip(s.nextTest(inDaysLabel(next.day, s)), tone: ToneKind.navy, icon: Icons.schedule)
          : TextButton(onPressed: () => context.push(testFormPath(kind: 'tsh', condition: 'thyroid', who: c.who)), child: Text(s.nextTestDate)),
      children: [
        TrendBars(points: pts, empty: s.noResults, unit: 'mIU/L'),
        if (chip != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            chip,
            const SizedBox(width: 8),
            if (l?.tshLow != null && l?.tshHigh != null)
              TextButton(onPressed: () => context.push(limitsPath(c.who)), child: Text(s.doctorRangeTsh(numText(l!.tshLow!, s, decimals: 2), numText(l.tshHigh!, s, decimals: 2)))),
          ]),
        ],
        const SizedBox(height: 6),
        Text(tr(thyroidRecheckNote, s.bn), style: TextStyle(color: p.muted, fontSize: 13)),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.push(testFormPath(kind: 'tsh', done: true, condition: 'thyroid', who: c.who)),
            icon: const Icon(Icons.add),
            label: Text(s.addResult),
          ),
        ),
      ],
    );
  }
}

// --- Cancer ------------------------------------------------------------------------

class CancerHero extends ConsumerWidget {
  const CancerHero(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final total = (c.setting['chemoTotal'] as num?)?.toInt();
    final done = (c.setting['chemoDone'] as num?)?.toInt() ?? 0;
    final today = dateOnly(DateTime.now());
    final soon = [
      ...c.records.appointments.where((a) => a.kind == AppointmentKind.chemo && !a.done && !a.day.isBefore(today)).map((a) => (a.day, a.time, s.chemoSession, a.remind)),
      ...c.records.upcomingTests.where((t) => !t.day.isBefore(today)).map((t) => (t.day, null as String?, testName(t.testKindCode, t.otherName, c.lookups, s.bn), t.remind)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    Future<void> save(Map<String, dynamic> m) => runCareAction(context, ref, () => CareActions(ref, c.who).updateSetting('cancer', m));
    return SectionCard(children: [
      Row(children: [
        Expanded(child: Text(s.chemoCycles, style: TextStyle(color: p.muted))),
        if (total != null) Text(s.chemoOf(done, total), style: TextStyle(color: p.violet, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      if (total == null)
        OutlinedButton(
          onPressed: () async {
            final controller = TextEditingController();
            final n = await showDialog<int>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(s.chemoPlan),
                content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
                  FilledButton(onPressed: () => Navigator.pop(ctx, parseNumber(controller.text)?.round()), child: Text(s.save)),
                ],
              ),
            );
            if (n == null || n < 1 || n > 50) return;
            await save({'chemoTotal': n, 'chemoDone': 0});
          },
          child: Text(s.chemoPlan),
        )
      else ...[
        Row(children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: i < done ? p.violet : p.track, borderRadius: BorderRadius.circular(999)),
              ),
            ),
        ]),
        if (done < total)
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => save({'chemoDone': done + 1}), child: Text(s.chemoDoneOne))),
      ],
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.violetContainer, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.comingUp, style: TextStyle(color: p.onVioletContainer, fontWeight: FontWeight.w700, fontSize: 13)),
          for (final (day, time, label, remind) in soon.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                DateBox(day: s.n(day.day), month: monthShort(day, s)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text([if (time != null) hhmmLabel(context, time, s), inDaysLabel(day, s)].join(', '), style: TextStyle(color: p.muted, fontSize: 13)),
                  ]),
                ),
                if (remind) StateChip(s.reminderOn, tone: ToneKind.navy, icon: Icons.check),
              ]),
            ),
          TextButton.icon(
            onPressed: () => context.push(visitFormPath(kind: 'CHEMO', condition: 'cancer', who: c.who)),
            icon: const Icon(Icons.add),
            label: Text(s.addChemoDate),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.violet),
            onPressed: () => context.push(testFormPath(kind: 'cbc', done: true, condition: 'cancer', who: c.who)),
            icon: const Icon(Icons.upload_outlined),
            label: Text(s.addReport),
          ),
        ),
      ]),
    ]);
  }
}
