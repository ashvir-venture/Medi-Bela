import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/core_providers.dart';
import '../domain/care_models.dart';
import '../domain/reading_rules.dart';
import 'care_providers.dart';
import 'care_widgets.dart';

/// One limit box: its API field, label, unit, range and decimals.
class _LimitSpec {
  const _LimitSpec(this.key, this.label, this.unit, this.min, this.max, {this.decimal = false, this.sugar = false});

  final String key;
  final String Function(Round15Strings s) label;
  final String Function(Round15Strings s, SugarUnit u) unit;
  final double min;
  final double max;
  final bool decimal;

  /// Stored in mmol/L, shown in the user's unit.
  final bool sugar;
}

String _mmHg(Round15Strings s, SugarUnit u) => 'mmHg';

final _sugarSpecs = [
  _LimitSpec('fastingLow', (s) => s.limFastLo, (s, u) => sugarUnitText(u), 1, 30, decimal: true, sugar: true),
  _LimitSpec('fastingHigh', (s) => s.limFastHi, (s, u) => sugarUnitText(u), 1, 30, decimal: true, sugar: true),
  _LimitSpec('afterFoodHigh', (s) => s.limAfterHi, (s, u) => sugarUnitText(u), 1, 30, decimal: true, sugar: true),
  _LimitSpec('lowSugar', (s) => s.limLow, (s, u) => sugarUnitText(u), 1, 30, decimal: true, sugar: true),
  _LimitSpec('hba1cTarget', (s) => s.limHba1c, (s, u) => '%', 4, 14, decimal: true),
];
final _bpSpecs = [
  _LimitSpec('bpSystolicHigh', (s) => s.limBpSys, _mmHg, 90, 200),
  _LimitSpec('bpDiastolicHigh', (s) => s.limBpDia, _mmHg, 50, 130),
  _LimitSpec('bpSystolicLow', (s) => s.limBpLow, _mmHg, 60, 130),
  _LimitSpec('bpCrisisSystolic', (s) => s.limCritS, _mmHg, 140, 220),
  _LimitSpec('bpCrisisDiastolic', (s) => s.limCritD, _mmHg, 90, 140),
];
_LimitSpec _spec(String key) => {
      'feverAboveF': _LimitSpec('feverAboveF', (s) => s.limFever, (s, u) => '°F', 98, 104, decimal: true),
      'weightGoalKg': _LimitSpec('weightGoalKg', (s) => s.limWGoal, (s, u) => s.kg, 20, 200, decimal: true),
      'waterGlasses': _LimitSpec('waterGlasses', (s) => s.limWater, (s, u) => s.glassesUnit, 1, 20),
      'sleepHours': _LimitSpec('sleepHours', (s) => s.limSleep, (s, u) => s.hoursUnit, 3, 12, decimal: true),
      'weightGain3Days': _LimitSpec('weightGain3Days', (s) => s.limWGain, (s, u) => s.kg, 0.5, 5, decimal: true),
      'fluidLimitMl': _LimitSpec('fluidLimitMl', (s) => s.limFluid, (s, u) => s.ml, 0, 5000),
      'peakFlowBest': _LimitSpec('peakFlowBest', (s) => s.limPf, (s, u) => 'L/min', 100, 800),
      'tshLow': _LimitSpec('tshLow', (s) => s.limTshLo, (s, u) => 'mIU/L', 0.01, 10, decimal: true),
      'tshHigh': _LimitSpec('tshHigh', (s) => s.limTshHi, (s, u) => 'mIU/L', 0.1, 20, decimal: true),
    }[key]!;

/// "Targets and limits" (Round 15 C): the doctor's numbers, typed by the
/// user or their caregiver. An empty box = not set = no range chip and no
/// alert for that kind (owner, 2026-11-11). The crisis sheets keep their
/// fixed levels; only the BP emergency level can be changed here.
class LimitsScreen extends ConsumerStatefulWidget {
  const LimitsScreen({super.key, this.who = const CareSubject()});

  final CareSubject who;

  @override
  ConsumerState<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends ConsumerState<LimitsScreen> {
  final _fields = <String, TextEditingController>{};
  final _doctor = TextEditingController();
  SugarUnit _unit = SugarUnit.mmol;
  bool _notify = true;
  bool _loaded = false;
  bool _saving = false;
  final _errors = <String, String>{};

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _doctor.dispose();
    super.dispose();
  }

  void _load(HealthLimits l, Round15Strings s) {
    _unit = l.sugarUnit;
    _notify = l.notifyFamily;
    _doctor.text = l.doctorNote ?? '';
    for (final spec in [..._sugarSpecs, ..._bpSpecs, ..._otherKeys.map(_spec)]) {
      final raw = l.field(spec.key) as num?;
      final shown = raw == null ? null : (spec.sugar ? fromMmol(raw.toDouble(), _unit) : raw.toDouble());
      _controller(spec.key).text = shown == null ? '' : (spec.sugar ? sugarText(raw!.toDouble(), _unit) : _plain(shown));
    }
    _loaded = true;
  }

  static const _otherKeys = ['feverAboveF', 'weightGoalKg', 'waterGlasses', 'sleepHours', 'weightGain3Days', 'fluidLimitMl', 'peakFlowBest', 'tshLow', 'tshHigh'];

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  TextEditingController _controller(String key) => _fields.putIfAbsent(key, TextEditingController.new);

  /// Switching mmol/L <-> mg/dL converts what is typed.
  void _switchUnit(SugarUnit to) {
    if (to == _unit) return;
    for (final spec in _sugarSpecs.where((x) => x.sugar)) {
      final v = parseNumber(_controller(spec.key).text);
      if (v != null) _controller(spec.key).text = sugarText(toMmol(v, _unit), to);
    }
    setState(() => _unit = to);
  }

  Future<void> _save(Round15Strings s, List<_LimitSpec> shown) async {
    final body = <String, dynamic>{'sugarUnit': _unit == SugarUnit.mgdl ? 'MGDL' : 'MMOL', 'notifyFamily': _notify, 'doctorNote': _doctor.text.trim().isEmpty ? null : _doctor.text.trim()};
    _errors.clear();
    for (final spec in shown) {
      final text = _controller(spec.key).text.trim();
      if (text.isEmpty) {
        body[spec.key] = null;
        continue;
      }
      final typed = parseNumber(text);
      final v = typed == null ? null : (spec.sugar ? toMmol(typed, _unit) : typed);
      final lo = spec.sugar ? spec.min : spec.min, hi = spec.max;
      if (v == null || v < lo - 1e-9 || v > hi + 1e-9) {
        final loShown = spec.sugar ? sugarText(lo, _unit) : _plain(lo);
        final hiShown = spec.sugar ? sugarText(hi, _unit) : _plain(hi);
        _errors[spec.key] = s.limitOutOfRange(loShown, hiShown);
        continue;
      }
      body[spec.key] = spec.decimal ? double.parse(v.toStringAsFixed(2)) : v.round();
    }
    void pair(String a, String b) {
      if (body[a] is num && body[b] is num && (body[a] as num) >= (body[b] as num)) _errors[a] = s.lowAboveHigh;
    }

    pair('fastingLow', 'fastingHigh');
    pair('tshLow', 'tshHigh');
    pair('bpSystolicLow', 'bpSystolicHigh');
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    final ok = await runCareAction(context, ref, () async {
      if (widget.who.isMember) {
        await ref.read(careApiProvider).updateLimits(body, forUserId: widget.who.memberId);
        invalidateMember(ref, widget.who);
      } else {
        await ref.read(careRepositoryProvider).updateLimits(body);
      }
    }, done: s.saved);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(ref).r15;
    final p = context.palette;
    final care = watchCareOf(ref, widget.who).valueOrNull;
    if (care != null && !_loaded) _load(care.limitsOrNone, s);
    final has = care?.has ?? (_) => false;
    final others = [
      'feverAboveF',
      'weightGoalKg',
      'waterGlasses',
      'sleepHours',
      if (has('heart')) 'weightGain3Days',
      if (has('kidney') || has('heart')) 'fluidLimitMl',
      if (has('asthma')) 'peakFlowBest',
      if (has('thyroid')) ...['tshLow', 'tshHigh'],
    ].map(_spec).toList();

    Widget row(_LimitSpec spec, {bool first = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: p.line3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(spec.label(s), style: const TextStyle(fontWeight: FontWeight.w600)))),
            const SizedBox(width: 10),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _controller(spec.key),
                keyboardType: TextInputType.numberWithOptions(decimal: spec.decimal),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                decoration: InputDecoration(suffixText: spec.unit(s, _unit), errorText: _errors[spec.key], errorMaxLines: 2, isDense: true),
              ),
            ),
          ]),
        );
    Widget section(IconData icon, ToneKind tone, String title, List<_LimitSpec> specs, {Widget? extra, String? hint}) => SectionCard(children: [
          Row(children: [IconTile(icon, tone: tone, size: 36), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)))]),
          const SizedBox(height: 8),
          ?extra,
          for (var i = 0; i < specs.length; i++) row(specs[i], first: i == 0),
          if (hint != null) ...[const SizedBox(height: 6), Text(hint, style: TextStyle(color: p.muted, fontSize: 13))],
        ]);

    final sugar = section(Icons.water_drop_outlined, ToneKind.primary, s.limSugar, _sugarSpecs,
        extra: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<SugarUnit>(
            segments: const [ButtonSegment(value: SugarUnit.mmol, label: Text('mmol/L')), ButtonSegment(value: SugarUnit.mgdl, label: Text('mg/dL'))],
            selected: {_unit},
            onSelectionChanged: (v) => _switchUnit(v.first),
          ),
        ));
    final bp = section(Icons.speed_outlined, ToneKind.navy, s.limBp, _bpSpecs, hint: s.limCritHint);
    final other = section(Icons.track_changes_outlined, ToneKind.ok, s.limOther, others);
    final bpFirst = has('bp') && !has('diabetes');

    return Scaffold(
      appBar: AppBar(title: Text(widget.who.isMember ? '${s.targetsLimits} · ${widget.who.memberName ?? ''}' : s.targetsLimits)),
      body: care == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  color: p.primaryContainer,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.shield_outlined, color: p.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.limitsIntroTitle, style: TextStyle(fontWeight: FontWeight.w700, color: p.onPrimaryContainer))),
                      ]),
                      const SizedBox(height: 6),
                      Text(s.limitsIntro, style: TextStyle(color: p.muted2)),
                    ]),
                  ),
                ),
                ...(bpFirst ? [bp, sugar] : [sugar, bp]),
                other,
                SectionCard(children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _notify,
                    onChanged: (v) => setState(() => _notify = v),
                    title: Text(s.tellFamily, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(s.tellFamilySub),
                  ),
                  TextField(controller: _doctor, decoration: InputDecoration(labelText: s.whichDoctorGave + s.optional, hintText: s.doctorNameDate)),
                ]),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : () => _save(s, [..._sugarSpecs, ..._bpSpecs, ...others]),
                  child: Text(s.save),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    for (final c in _fields.values) {
                      c.clear();
                    }
                  }),
                  child: Text(s.clearAll),
                ),
              ],
            ),
    );
  }
}
