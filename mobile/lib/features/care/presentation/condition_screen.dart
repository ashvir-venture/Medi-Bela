import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../health/domain/health_models.dart';
import '../domain/care_models.dart';
import '../domain/reading_rules.dart';
import 'care_blocks.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import 'condition_heroes.dart';
import 'medicine_tag.dart';
import 'reading_screen.dart';

/// One condition's page (Round 15 E), in the demo's order per condition:
/// a hero with its graph and latest values, "When to act", habits, "How do
/// you feel today?", Learn, regular tests, next visit and questions.
class ConditionScreen extends ConsumerStatefulWidget {
  const ConditionScreen({super.key, required this.code, this.who = const CareSubject()});

  final String code;
  final CareSubject who;

  @override
  ConsumerState<ConditionScreen> createState() => _ConditionScreenState();
}

class _ConditionScreenState extends ConsumerState<ConditionScreen> {
  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final lookups = ref.watch(careLookupsProvider).valueOrNull;
    final careAsync = watchCareOf(ref, widget.who);
    final records = watchRecordsOf(ref, widget.who).valueOrNull ?? RecordsOverview.empty;
    final readings = watchReadingsOf(ref, widget.who).valueOrNull ?? const <HealthRecordModel>[];
    final name = conditionName(widget.code, lookups, s.bn);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name),
          if (widget.who.isMember) Text(widget.who.memberName ?? '', style: TextStyle(fontSize: 13, color: p.muted)),
        ]),
      ),
      body: careAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(s.needsInternet)),
        data: (care) {
          final c = CareCtx(code: widget.code, care: care, records: records, readings: readings, lookups: lookups, who: widget.who, s: s);
          final blocks = <Widget>[
            ...switch (widget.code) {
              'diabetes' => [
                  // Sugar here; "Insulin and sites" opens the insulin log.
                  SegmentedButton<bool>(
                    segments: [ButtonSegment(value: false, label: Text(s.sugarTab)), ButtonSegment(value: true, label: Text(s.insulinTab))],
                    selected: const {false},
                    onSelectionChanged: (v) {
                      if (v.first) context.push(insulinPath(widget.who));
                    },
                  ),
                  DiabetesSugarHero(c),
                  DangerBlock(c),
                  MedicinesForBlock(c),
                  HabitsBlock(c),
                  LearnBlock(c),
                  RegularTestsBlock(c),
                  NextVisitBlock(c),
                  QuestionsBlock(c),
                ],
              'bp' => [BpHero(c), DangerBlock(c), MedicinesForBlock(c), HabitsBlock(c), SymptomsBlock(c), LearnBlock(c), RegularTestsBlock(c), NextVisitBlock(c), QuestionsBlock(c)],
              'pregnancy' => [
                  PregnancyHero(c),
                  DangerBlock(c),
                  AncBlock(c),
                  KicksBlock(c),
                  PregnancyVitalsBlock(c),
                  HabitsBlock(c),
                  SymptomsBlock(c),
                  RegularTestsBlock(c),
                  TdBlock(c),
                  BirthPlanBlock(c),
                  LearnBlock(c),
                  QuestionsBlock(c),
                ],
              'heart' => [HeartHero(c), DangerBlock(c), MedicinesForBlock(c), HabitsBlock(c), SymptomsBlock(c), LearnBlock(c), RegularTestsBlock(c), NextVisitBlock(c), QuestionsBlock(c)],
              'kidney' => [KidneyHero(c), DangerBlock(c), MedicinesForBlock(c), HabitsBlock(c), SymptomsBlock(c), LearnBlock(c), RegularTestsBlock(c), NextVisitBlock(c), QuestionsBlock(c)],
              'asthma' => [AsthmaHero(c), DangerBlock(c), MedicinesForBlock(c), HabitsBlock(c), SymptomsBlock(c), LearnBlock(c), RegularTestsBlock(c), NextVisitBlock(c), QuestionsBlock(c)],
              'thyroid' => [ThyroidHero(c), MedicinesForBlock(c), HabitsBlock(c), SymptomsBlock(c), LearnBlock(c), RegularTestsBlock(c), NextVisitBlock(c), DangerBlock(c), QuestionsBlock(c)],
              'cancer' => [CancerHero(c), DangerBlock(c), MedicinesForBlock(c), HabitsBlock(c), SymptomsBlock(c), LearnBlock(c), RegularTestsBlock(c), NextVisitBlock(c), QuestionsBlock(c)],
              // A condition the owner added without a page of its own.
              _ => [RegularTestsBlock(c), NextVisitBlock(c), QuestionsBlock(c)],
            },
          ];
          return RefreshIndicator(
            onRefresh: () async {
              if (widget.who.isMember) {
                invalidateMember(ref, widget.who);
              } else {
                await runCareAction(context, ref, () => ref.read(careRepositoryProvider).refreshAll());
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [for (final b in blocks) Padding(padding: const EdgeInsets.only(bottom: 10), child: b)],
            ),
          );
        },
      ),
    );
  }
}

/// A one-line summary of a condition for the Health tab and Home.
String careSummary(String code, CareOverview care, RecordsOverview records, List<HealthRecordModel> readings, Round15Strings s, CareLookups? lookups) {
  HealthRecordModel? last(String type, [String? ctx]) {
    for (final r in readings) {
      if (r.type == type && (ctx == null || r.sugarContext == ctx)) return r;
    }
    return null;
  }

  final unit = care.limitsOrNone.sugarUnit;
  switch (code) {
    case 'diabetes':
      final r = last('BLOOD_SUGAR');
      return r?.numericValue == null ? s.noneYet : '${s.tSugar}: ${s.n(sugarText(r!.numericValue!, unit))} ${sugarUnitText(unit)}, ${dayLabel(r.recordedAt, s)}';
    case 'bp':
    case 'heart':
      final r = last(code == 'heart' ? 'WEIGHT' : 'BLOOD_PRESSURE');
      if (r == null) return s.noneYet;
      return code == 'heart'
          ? '${s.tWeight}: ${numText(r.numericValue ?? 0, s)} ${s.kg}, ${dayLabel(r.recordedAt, s)}'
          : '${s.n(r.value)} mmHg, ${dayLabel(r.recordedAt, s)}';
    case 'pregnancy':
      final due = care.setting('pregnancy')['dueDate'];
      if (due is! String) return s.addDueDate;
      final days = 280 - parseDate(due).difference(dateOnly(DateTime.now())).inDays;
      return s.weeksDays(days ~/ 7, days % 7);
    case 'kidney':
    case 'thyroid':
      final kind = code == 'kidney' ? 'kidney' : 'tsh';
      final results = records.resultsOf(kind);
      return results.isEmpty ? s.noResults : s.lastResult(shortDate(results.last.day, s));
    case 'asthma':
      final days = care.logs.where((l) => l.kind == CareLogKind.reliever && DateTime.now().difference(l.loggedAt).inDays < 7).map((l) => isoDate(l.loggedAt)).toSet().length;
      return '${s.reliever}: ${s.daysCount(days)} ${s.thisWeek}';
    case 'cancer':
      final total = (care.setting('cancer')['chemoTotal'] as num?)?.toInt();
      final done = (care.setting('cancer')['chemoDone'] as num?)?.toInt() ?? 0;
      return total == null ? s.chemoCycles : '${s.chemoCycles}: ${s.chemoOf(done, total)}';
  }
  return conditionSubtitle(code, lookups, s.bn) ?? '';
}

/// The "My care" list (Health tab) and Home cards: one row per condition.
class CareConditionTile extends StatelessWidget {
  const CareConditionTile({super.key, required this.code, required this.name, required this.summary, this.who = const CareSubject()});

  final String code;
  final String name;
  final String summary;
  final CareSubject who;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: IconTile(conditionIcon(code), tone: switch (code) {
          'heart' => ToneKind.error,
          'cancer' => ToneKind.violet,
          'thyroid' => ToneKind.ok,
          'pregnancy' => ToneKind.warn,
          'bp' || 'kidney' => ToneKind.navy,
          _ => ToneKind.primary,
        }),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(conditionPath(code, who)),
      ),
    );
  }
}
