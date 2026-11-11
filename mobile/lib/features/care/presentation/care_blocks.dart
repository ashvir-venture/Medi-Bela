import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../../help/presentation/help_screens.dart';
import '../../health/domain/health_models.dart';
import '../domain/care_content.dart';
import '../domain/care_models.dart';
import '../domain/reading_rules.dart';
import 'care_actions.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import 'reading_screen.dart';

/// What every condition block needs.
class CareCtx {
  const CareCtx({required this.code, required this.care, required this.records, required this.readings, required this.lookups, required this.who, required this.s});

  final String code;
  final CareOverview care;
  final RecordsOverview records;
  /// Newest first.
  final List<HealthRecordModel> readings;
  final CareLookups? lookups;
  final CareSubject who;
  final Round15Strings s;

  ConditionContent get content => contentOf(code);

  List<HealthRecordModel> of(String type) => [for (final r in readings) if (r.type == type) r];
  HealthRecordModel? last(String type, {String? sugarContext}) {
    for (final r in readings) {
      if (r.type == type && (sugarContext == null || r.sugarContext == sugarContext)) return r;
    }
    return null;
  }
  Map<String, dynamic> get setting => care.setting(code);

  /// The care plan: habits and tests saved, else the condition's suggestions.
  List<String> get habits => [for (final h in (setting['habits'] as List? ?? content.habits.map((h) => h.key))) h as String];
  Map<String, String> get customHabits => {
        for (final e in (Map<String, dynamic>.from(setting['customHabits'] as Map? ?? {})).entries) e.key: e.value as String,
      };
  List<String> get tests => [for (final t in (setting['tests'] as List? ?? content.tests)) t as String];
  Map<String, int> get testEvery => {
        for (final e in (Map<String, dynamic>.from(setting['testEveryMonths'] as Map? ?? {})).entries) e.key: (e.value as num).toInt(),
      };
}

/// "When to act right away" (red outline, open or tap to open) with Call 999 / 16263.
class DangerBlock extends ConsumerStatefulWidget {
  const DangerBlock(this.c, {super.key});

  final CareCtx c;

  @override
  ConsumerState<DangerBlock> createState() => _DangerBlockState();
}

class _DangerBlockState extends ConsumerState<DangerBlock> {
  bool? _open;

  @override
  Widget build(BuildContext context) {
    final d = widget.c.content.danger;
    if (d == null) return const SizedBox.shrink();
    final s = widget.c.s;
    final p = context.palette;
    final open = _open ?? d.openByDefault;
    return SectionCard(outlineError: true, children: [
      InkWell(
        onTap: () => setState(() => _open = !open),
        child: Row(children: [
          const IconTile(Icons.warning_amber_rounded, tone: ToneKind.error, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(d.title, s.bn), style: TextStyle(color: p.later, fontWeight: FontWeight.w700, fontSize: 16)),
              Text(open ? s.rememberShare : s.whenToAct, style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
          Icon(open ? Icons.expand_less : Icons.expand_more),
        ]),
      ),
      if (open) ...[
        const SizedBox(height: 8),
        for (final item in d.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(tr(item, s.bn)))]),
          ),
      ],
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: p.later, foregroundColor: p.onLater),
            onPressed: () => openExternal(context, ref, 'tel:999', fallbackCopy: '999'),
            icon: const Icon(Icons.phone, size: 18),
            label: Text(s.call999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => openExternal(context, ref, 'tel:16263', fallbackCopy: '16263'),
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: Text(s.call16263),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text(tr(helpline16263, s.bn), style: TextStyle(color: p.muted, fontSize: 12)),
    ]);
  }
}

/// Today's habits: tick today, 7-day dots; Edit adds (suggestions or typed) or removes.
class HabitsBlock extends ConsumerStatefulWidget {
  const HabitsBlock(this.c, {super.key});

  final CareCtx c;

  @override
  ConsumerState<HabitsBlock> createState() => _HabitsBlockState();
}

class _HabitsBlockState extends ConsumerState<HabitsBlock> {
  bool _edit = false;
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _savePlan(List<String> habits, Map<String, String> custom) => runCareAction(
        context,
        ref,
        () => CareActions(ref, widget.c.who).updateSetting(widget.c.code, {'habits': habits, 'customHabits': custom}),
      );

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.s;
    final p = context.palette;
    final now = DateTime.now();
    final habits = c.habits;
    final custom = c.customHabits;
    Bi? label(String k) => habitLabel(k, c.code, custom);
    final suggestions = {
      ...c.content.habits.map((h) => h.key),
      ...habitPool.map((h) => h.key),
    }.where((k) => !habits.contains(k)).toList();

    return SectionCard(
      title: s.todaysHabits,
      trailing: TextButton.icon(
        onPressed: () => setState(() => _edit = !_edit),
        icon: Icon(_edit ? Icons.check : Icons.tune, size: 18),
        label: Text(_edit ? s.done : s.edit),
      ),
      children: [
        if (habits.isEmpty) Text(s.noHabits, style: TextStyle(color: p.muted)),
        for (final key in habits)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              if (_edit)
                IconButton(
                  tooltip: s.remove,
                  color: p.later,
                  onPressed: () => _savePlan([...habits]..remove(key), {...custom}..remove(key)),
                  icon: const Icon(Icons.close),
                )
              else
                Checkbox(
                  value: c.care.ticked('habit:$key', now),
                  onChanged: (v) => runCareAction(context, ref, () => CareActions(ref, c.who).setTick('habit:$key', now, v ?? false)),
                ),
              Expanded(child: Text(label(key) == null ? key : tr(label(key)!, s.bn))),
              if (!_edit) SevenDots(sevenDayDots((d) => c.care.ticked('habit:$key', d), now)),
            ]),
          ),
        if (_edit) ...[
          const Divider(),
          Text(s.add, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in suggestions)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(tr(label(k)!, s.bn)),
                onPressed: () => _savePlan([...habits, k], custom),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _typed, decoration: InputDecoration(hintText: s.ownHabit))),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final text = _typed.text.trim();
                if (text.isEmpty) return;
                final key = 'u_${Random().nextInt(1 << 30).toRadixString(36)}';
                _typed.clear();
                _savePlan([...habits, key], {...custom, key: text});
              },
              child: Text(s.add),
            ),
          ]),
        ],
      ],
    );
  }
}

/// "How do you feel today?": pick symptoms (red = urgent → call 999 box), Save or "I feel fine".
class SymptomsBlock extends ConsumerStatefulWidget {
  const SymptomsBlock(this.c, {super.key});

  final CareCtx c;

  @override
  ConsumerState<SymptomsBlock> createState() => _SymptomsBlockState();
}

class _SymptomsBlockState extends ConsumerState<SymptomsBlock> {
  final _picked = <String>{};

  Future<void> _save({required bool fine}) async {
    final s = widget.c.s;
    final ok = await runCareAction(
      context,
      ref,
      () => CareActions(ref, widget.c.who).addLog(CareLogKind.symptoms, {'symptoms': fine ? <String>[] : _picked.toList(), 'fine': fine}, condition: widget.c.code),
      done: s.saved,
    );
    if (ok && mounted) setState(_picked.clear);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final list = c.content.symptoms;
    if (list.isEmpty) return const SizedBox.shrink();
    final s = c.s;
    final p = context.palette;
    final urgent = list.any((x) => x.urgent && _picked.contains(x.key));
    final last = c.care.logs.where((l) => l.kind == CareLogKind.symptoms && l.conditionCode == c.code).fold<CareLog?>(
          null,
          (a, b) => a == null || b.loggedAt.isAfter(a.loggedAt) ? b : a,
        );
    return SectionCard(
      title: s.howFeel,
      trailing: last == null ? null : Text(s.lastOn(dayLabel(last.loggedAt, s)), style: TextStyle(color: p.muted, fontSize: 13)),
      subtitle: s.howFeelSub,
      children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final x in list)
            PillButton(
              label: tr(x.text, s.bn),
              selected: _picked.contains(x.key),
              urgent: x.urgent,
              onTap: () => setState(() => _picked.contains(x.key) ? _picked.remove(x.key) : _picked.add(x.key)),
            ),
        ]),
        if (urgent) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr(urgentSignNote, s.bn), style: TextStyle(color: p.onErrorContainer, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: p.later, foregroundColor: p.onLater),
                    onPressed: () => openExternal(context, ref, 'tel:999', fallbackCopy: '999'),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(s.call999),
                  ),
                ),
                if (!c.who.isMember) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final told = await ref.read(careRepositoryProvider).alertFamily();
                          messenger.showSnackBar(SnackBar(content: Text(told ? s.alertSent : s.alertNobody)));
                        } catch (_) {
                          messenger.showSnackBar(SnackBar(content: Text(s.needsInternet)));
                        }
                      },
                      icon: const Icon(Icons.groups_outlined, size: 18),
                      label: Text(s.alertFamily),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _save(fine: true), icon: const Icon(Icons.sentiment_satisfied_alt, size: 18), label: Text(s.feelFine))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: _picked.isEmpty ? null : () => _save(fine: false), child: Text(s.save))),
        ]),
      ],
    );
  }
}

/// A "Learn" card, closed until tapped.
class LearnBlock extends StatefulWidget {
  const LearnBlock(this.c, {super.key});

  final CareCtx c;

  @override
  State<LearnBlock> createState() => _LearnBlockState();
}

class _LearnBlockState extends State<LearnBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.c.content.learn;
    if (l == null) return const SizedBox.shrink();
    final s = widget.c.s;
    final p = context.palette;
    return Card(
      color: p.surface2,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(children: [
              Icon(Icons.info_outline, color: p.link),
              const SizedBox(width: 8),
              Expanded(child: Text(tr(l.title, s.bn), style: const TextStyle(fontWeight: FontWeight.w700))),
              Icon(_open ? Icons.expand_less : Icons.expand_more),
            ]),
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < l.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.n(i + 1)}.  '),
                  Expanded(child: Text(tr(l.items[i], s.bn))),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

/// Regular tests: last result, how often, due date or the next booked date.
class RegularTestsBlock extends ConsumerStatefulWidget {
  const RegularTestsBlock(this.c, {super.key});

  final CareCtx c;

  @override
  ConsumerState<RegularTestsBlock> createState() => _RegularTestsBlockState();
}

class _RegularTestsBlockState extends ConsumerState<RegularTestsBlock> {
  bool _edit = false;

  Future<void> _save(List<String> tests, Map<String, int> every) =>
      runCareAction(context, ref, () => CareActions(ref, widget.c.who).updateSetting(widget.c.code, {'tests': tests, 'testEveryMonths': every}));

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.s;
    final p = context.palette;
    final tests = c.tests;
    final every = c.testEvery;
    final allKinds = [for (final k in c.lookups?.testKinds ?? const <TestKind>[]) k.code].where((k) => k != 'checkup' && !tests.contains(k)).toList();

    Widget row(String code) {
      final done = c.records.resultsOf(code);
      final last = done.isEmpty ? null : done.last;
      final next = c.records.upcomingTests.where((t) => t.testKindCode == code).firstOrNull;
      final freq = every[code] ?? 0;
      final due = testDue(last?.day, freq);
      final name = testName(code, null, c.lookups, s.bn);
      if (_edit) {
        return Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
          child: Row(children: [
            IconButton(color: p.later, tooltip: s.remove, onPressed: () => _save([...tests]..remove(code), {...every}..remove(code)), icon: const Icon(Icons.close)),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
            DropdownButton<int>(
              value: freq,
              items: [for (final m in testEveryChoices) DropdownMenuItem(value: m, child: Text(s.everyMonths(m)))],
              onChanged: (m) => _save(tests, {...every, code: m ?? 0}),
            ),
          ]),
        );
      }
      final sub = [
        last == null ? s.notRecorded : s.lastResult(shortDate(last.day, s)),
        if (freq > 0) s.everyMonths(freq),
      ].join(', ');
      final overdue = due != null && due.isBefore(dateOnly(DateTime.now()));
      return Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line3))),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: TextStyle(color: p.muted, fontSize: 13)),
              if (next == null && due != null)
                Text(overdue ? s.wasDue(shortDate(due, s)) : s.dueOn(shortDate(due, s)),
                    style: TextStyle(color: overdue ? p.onWarnContainer : p.muted, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
          if (next != null)
            StateChip(inDaysLabel(next.day, s), tone: next.day.difference(DateTime.now()).inDays <= 7 ? ToneKind.warn : ToneKind.navy, icon: Icons.schedule)
          else
            OutlinedButton(
              style: compactOutlined,
              onPressed: () => context.push(testFormPath(kind: code, condition: c.code, who: c.who)),
              child: Text(due != null ? s.schedule : s.addDate),
            ),
        ]),
      );
    }

    return SectionCard(
      title: s.regularTests,
      subtitle: _edit ? s.regularTestsEdit : s.regularTestsSub,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!_edit) TextButton(onPressed: () => context.push(recordsPath(c.who)), child: Text(s.allRecords)),
        TextButton.icon(onPressed: () => setState(() => _edit = !_edit), icon: Icon(_edit ? Icons.check : Icons.tune, size: 18), label: Text(_edit ? s.done : s.edit)),
      ]),
      children: [
        if (tests.isEmpty) Text(s.noTests, style: TextStyle(color: p.muted)),
        for (final t in tests) row(t),
        if (_edit && allKinds.isNotEmpty) ...[
          const Divider(),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in allKinds)
              ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(testName(k, null, c.lookups, s.bn)), onPressed: () => _save([...tests, k], every)),
          ]),
        ],
      ],
    );
  }
}

/// The next doctor visit for this condition (or "add the date").
class NextVisitBlock extends ConsumerWidget {
  const NextVisitBlock(this.c, {super.key});

  final CareCtx c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.s;
    final p = context.palette;
    final today = dateOnly(DateTime.now());
    final next = c.records.appointments
        .where((a) => a.kind == AppointmentKind.visit && a.conditionCode == c.code && !a.day.isBefore(today))
        .firstOrNull;
    if (next == null) {
      return SectionCard(title: s.nextVisit, subtitle: s.nextVisitSub, children: [
        FilledButton.icon(
          onPressed: () => context.push(visitFormPath(condition: c.code, who: c.who)),
          icon: const Icon(Icons.add),
          label: Text(s.addVisit),
        ),
      ]);
    }
    final doctor = next.doctor;
    final line = [
      if (doctor != null) doctor.name else s.doctorNotAdded,
      if (doctor != null && doctor.line.isNotEmpty) doctor.line,
      if (next.time != null) hhmmLabel(context, next.time!, s),
    ].join(', ');
    return SectionCard(children: [
      InkWell(
        onTap: () => context.push(visitFormPath(id: next.id, condition: c.code, who: c.who)),
        child: Row(children: [
          DateBox(day: s.n(next.day.day), month: monthShort(next.day, s)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.doctorVisit}, ${inDaysLabel(next.day, s)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(line, style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/health/records/pdf'), icon: const Icon(Icons.description_outlined, size: 18), label: Text(s.takeReport))),
        const SizedBox(width: 8),
        Expanded(
          child: TextButton(
            onPressed: () => context.push(c.code == 'bp' ? limitsPath(c.who) : recordsPath(c.who)),
            child: Text(c.code == 'bp' ? s.checkLimits : s.seeRecords),
          ),
        ),
      ]),
    ]);
  }
}

/// "Questions for my doctor".
class QuestionsBlock extends ConsumerStatefulWidget {
  const QuestionsBlock(this.c, {super.key});

  final CareCtx c;

  @override
  ConsumerState<QuestionsBlock> createState() => _QuestionsBlockState();
}

class _QuestionsBlockState extends ConsumerState<QuestionsBlock> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = c.s;
    final p = context.palette;
    return SectionCard(title: s.questions, children: [
      if (c.care.questions.isEmpty) Text(s.noQuestions, style: TextStyle(color: p.muted)),
      for (final q in c.care.questions)
        Row(children: [
          Icon(Icons.sticky_note_2_outlined, size: 18, color: p.link),
          const SizedBox(width: 8),
          Expanded(child: Text(q.text)),
          IconButton(
            tooltip: s.delete,
            onPressed: () => runCareAction(context, ref, () => CareActions(ref, c.who).deleteQuestion(q.id)),
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: TextField(controller: _text, maxLength: 300, decoration: InputDecoration(hintText: s.writeQuestion, counterText: ''))),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () async {
            final text = _text.text.trim();
            if (text.isEmpty) return;
            final ok = await runCareAction(context, ref, () => CareActions(ref, c.who).addQuestion(text));
            if (ok) _text.clear();
          },
          child: Text(s.add),
        ),
      ]),
    ]);
  }
}
