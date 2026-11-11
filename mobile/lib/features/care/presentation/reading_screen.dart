import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../providers/core_providers.dart';
import '../domain/care_content.dart';
import '../domain/care_models.dart';
import '../domain/reading_rules.dart';
import 'care_providers.dart';
import 'care_widgets.dart';
import 'crisis_sheet.dart';

/// The reading kinds the form offers (API types).
const readingTypes = ['BLOOD_SUGAR', 'BLOOD_PRESSURE', 'WEIGHT', 'TEMPERATURE', 'INSULIN', 'SLEEP', 'WATER', 'PEAK_FLOW'];

IconData readingIcon(String type) => switch (type) {
      'BLOOD_SUGAR' => Icons.water_drop_outlined,
      'BLOOD_PRESSURE' => Icons.speed_outlined,
      'WEIGHT' => Icons.monitor_weight_outlined,
      'TEMPERATURE' => Icons.thermostat_outlined,
      'INSULIN' => Icons.vaccines_outlined,
      'SLEEP' => Icons.bedtime_outlined,
      'WATER' => Icons.local_drink_outlined,
      'PEAK_FLOW' => Icons.air,
      _ => Icons.monitor_heart_outlined,
    };

String readingTypeName(String type, Round15Strings s) => switch (type) {
      'BLOOD_SUGAR' => s.tSugar,
      'BLOOD_PRESSURE' => s.tBp,
      'WEIGHT' => s.tWeight,
      'TEMPERATURE' => s.tTemp,
      'INSULIN' => s.tInsulin,
      'SLEEP' => s.tSleep,
      'WATER' => s.tWater,
      'PEAK_FLOW' => s.tPeakFlow,
      _ => type,
    };

/// "Log a reading" (Round 15 B): sugar (when checked), BP (two measurements
/// averaged, arm, pulse), weight with BMI (height asked once), temperature,
/// insulin units and site, sleep, water, peak flow. Own readings save on the
/// phone first (offline) and sync; a caregiver's entry for a member is online.
/// Judged against the saved limits; a dangerous one opens the crisis sheet.
class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key, this.initialType, this.who = const CareSubject()});

  final String? initialType;
  final CareSubject who;

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  late String _type = readingTypes.contains(widget.initialType) ? widget.initialType! : 'BLOOD_SUGAR';
  String _context = 'FASTING';
  String? _arm;
  String _site = 'LEFT_ABDOMEN';
  double _hours = 7;
  int _glasses = 6;
  TimeOfDay _at = TimeOfDay.now();
  String? _error;
  bool _saving = false;
  final _v = TextEditingController();
  final _s1 = TextEditingController();
  final _d1 = TextEditingController();
  final _s2 = TextEditingController();
  final _d2 = TextEditingController();
  final _pulse = TextEditingController();
  final _height = TextEditingController();

  @override
  void dispose() {
    for (final c in [_v, _s1, _d1, _s2, _d2, _pulse, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchType(String t) => setState(() {
        _type = t;
        _error = null;
      });

  int? _int(TextEditingController c) => parseNumber(c.text)?.round();

  Future<void> _save(CareOverview care) async {
    final s = stringsOf(ref).r15;
    final limits = care.limits;
    final unit = care.limitsOrNone.sugarUnit;
    final now = DateTime.now();
    final recordedAt = DateTime(now.year, now.month, now.day, _at.hour, _at.minute);
    var value = '';
    String? unitText;
    final details = <String, dynamic>{};
    RangeState? range;
    CrisisKind? crisis;
    String crisisReading = '';

    switch (_type) {
      case 'BLOOD_PRESSURE':
        final s1 = _int(_s1), d1 = _int(_d1);
        if (s1 == null || d1 == null || s1 <= 50 || s1 >= 260 || d1 <= 30 || d1 >= 160) {
          setState(() => _error = s.enterBoth);
          return;
        }
        int? s2 = _int(_s2), d2 = _int(_d2);
        if (s2 == null || d2 == null || s2 <= 50 || s2 >= 260 || d2 <= 30 || d2 >= 160) s2 = d2 = null;
        final avg = bpAverage(s1, d1, s2, d2);
        value = '${avg.systolic}/${avg.diastolic}';
        unitText = 'mmHg';
        details.addAll({
          'systolic': avg.systolic,
          'diastolic': avg.diastolic,
          'measurements': avg.measurements,
          if (_int(_pulse) != null && _int(_pulse)! >= 20 && _int(_pulse)! <= 250) 'pulse': _int(_pulse),
          'bpArm': ?_arm,
        });
        range = bpRange(avg.systolic, avg.diastolic, limits);
        if (isBpCrisis(avg.systolic, avg.diastolic, limits, pregnant: care.has('pregnancy'))) {
          crisis = CrisisKind.bp;
          crisisReading = '${s.n(value)} mmHg';
        }
      case 'SLEEP':
        value = _hours.toString();
        details['numericValue'] = _hours;
        unitText = 'h';
      case 'WATER':
        value = '$_glasses';
        details['numericValue'] = _glasses.toDouble();
        unitText = 'glasses';
      default:
        final v = parseNumber(_v.text);
        if (v == null || v <= 0) {
          setState(() => _error = s.enterNumber);
          return;
        }
        if (_type == 'BLOOD_SUGAR') {
          final mmol = toMmol(v, unit);
          if (mmol < 0.5 || mmol > 40) {
            setState(() => _error = s.numberOutOfRange);
            return;
          }
          details.addAll({'numericValue': double.parse(mmol.toStringAsFixed(2)), 'sugarContext': _context});
          value = sugarText(mmol, unit);
          unitText = sugarUnitText(unit);
          range = sugarRange(mmol, _context, limits);
          if (isSugarCrisis(mmol)) {
            crisis = CrisisKind.sugar;
            crisisReading = '${s.n(value)} $unitText';
          }
        } else {
          final bounds = switch (_type) {
            'WEIGHT' => (1.0, 400.0),
            'TEMPERATURE' => (90.0, 110.0),
            'INSULIN' => (0.5, 200.0),
            _ => (50.0, 900.0),
          };
          if (v < bounds.$1 || v > bounds.$2) {
            setState(() => _error = s.numberOutOfRange);
            return;
          }
          details['numericValue'] = v;
          value = numText(v, const Round15Strings(false));
          unitText = switch (_type) { 'WEIGHT' => 'kg', 'TEMPERATURE' => '°F', 'INSULIN' => 'units', _ => 'L/min' };
          if (_type == 'TEMPERATURE') range = feverRange(v, limits);
          if (_type == 'INSULIN') details['injectionSite'] = _site;
        }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await runCareAction(context, ref, () async {
      if (widget.who.isMember) {
        await ref.read(healthApiProvider).createRecord(
              type: _type,
              value: value,
              unit: unitText,
              recordedAt: recordedAt,
              details: details,
              forUserId: widget.who.memberId,
            );
        invalidateMember(ref, widget.who);
      } else {
        await ref.read(healthRecordRepositoryProvider).create(
              type: _type,
              value: value,
              unit: unitText,
              recordedAt: recordedAt,
              details: details,
            );
        // Height, asked once with the first weight (online, best effort).
        final h = _int(_height);
        if (_type == 'WEIGHT' && care.heightCm == null && h != null && h >= 50 && h <= 250) {
          try {
            await ref.read(authControllerProvider.notifier).updateProfile({'heightCm': h});
            await ref.read(careRepositoryProvider).refreshCare();
          } catch (_) {}
        }
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;

    final messenger = ScaffoldMessenger.of(context);
    if (crisis != null) {
      final level = bpCrisisLevel(limits, pregnant: care.has('pregnancy'));
      final again = await showCrisisSheet(
        context,
        kind: crisis,
        reading: crisisReading,
        level: '${level.systolic}/${level.diastolic}',
        forMember: widget.who.isMember,
      );
      if (!mounted) return;
      if (again) {
        for (final c in [_v, _s1, _d1, _s2, _d2, _pulse]) {
          c.clear();
        }
        setState(() => _at = TimeOfDay.now());
        return;
      }
      context.pop();
      return;
    }
    final told = (range == RangeState.above || range == RangeState.below) && (limits?.notifyFamily ?? false) && !widget.who.isMember;
    final msg = switch (range) {
      RangeState.inRange => s.savedInRange,
      RangeState.above => (_type == 'TEMPERATURE' ? s.savedFever : s.savedAbove) + (told ? s.familyTold : ''),
      RangeState.below => (_type == 'BLOOD_SUGAR' ? s.savedBelowSugar : s.savedBelowBp) + (told ? s.familyTold : ''),
      null => s.saved,
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = stringsOf(ref);
    final s = strings.r15;
    final p = context.palette;
    final care = watchCareOf(ref, widget.who).valueOrNull ?? CareOverview.empty;
    final l = care.limits;
    final unit = care.limitsOrNone.sugarUnit;

    Widget bigField(TextEditingController c, String label) => TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          decoration: InputDecoration(labelText: label),
        );
    Widget rangeNote(String text) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(child: Text(text)),
            TextButton(onPressed: () => context.push(limitsPath(widget.who)), child: Text(s.change)),
          ]),
        );

    final form = <Widget>[];
    switch (_type) {
      case 'BLOOD_SUGAR':
        form.addAll([
          Text(s.whenChecked, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in sugarContexts)
              PillButton(label: tr(sugarContextNames[c]!, s.bn), selected: _context == c, square: true, onTap: () => setState(() => _context = c)),
          ]),
          const SizedBox(height: 14),
          bigField(_v, s.sugarField(sugarUnitText(unit))),
          const SizedBox(height: 10),
          rangeNote(l != null && l.hasSugar
              ? s.doctorsRange +
                  [
                    if (l.fastingLow != null && l.fastingHigh != null) s.rangeFasting(sugarText(l.fastingLow!, unit), sugarText(l.fastingHigh!, unit)),
                    if (l.afterFoodHigh != null) '${s.limAfterHi}: ${s.n(sugarText(l.afterFoodHigh!, unit))}',
                  ].join(', ')
              : s.noLimitYet),
        ]);
      case 'BLOOD_PRESSURE':
        form.addAll([
          Row(children: [Expanded(child: bigField(_s1, s.upper)), const SizedBox(width: 10), Expanded(child: bigField(_d1, s.lower))]),
          const SizedBox(height: 10),
          bigField(_pulse, s.pulseOptional),
          const SizedBox(height: 14),
          Text(s.measureAgain + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: bigField(_s2, s.upperShort)), const SizedBox(width: 10), Expanded(child: bigField(_d2, s.lowerShort))]),
          const SizedBox(height: 4),
          Text(s.averageNote, style: TextStyle(color: p.muted, fontSize: 13)),
          const SizedBox(height: 14),
          Text(s.whichArm + s.optional, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            PillButton(label: s.leftArm, selected: _arm == 'LEFT', onTap: () => setState(() => _arm = _arm == 'LEFT' ? null : 'LEFT')),
            const SizedBox(width: 8),
            PillButton(label: s.rightArm, selected: _arm == 'RIGHT', onTap: () => setState(() => _arm = _arm == 'RIGHT' ? null : 'RIGHT')),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push(conditionPath('bp', widget.who)),
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(s.howToMeasure),
            ),
          ),
          rangeNote(l != null && l.hasBp && l.bpSystolicHigh != null && l.bpDiastolicHigh != null
              ? '${s.doctorsRange}${s.rangeBp(l.bpSystolicHigh!, l.bpDiastolicHigh!)}'
              : s.noLimitYet),
        ]);
      case 'WEIGHT':
        final w = parseNumber(_v.text);
        final h = care.heightCm ?? _int(_height);
        final b = w == null ? null : bmi(w, h);
        form.addAll([
          bigField(_v, s.weightKg),
          if (care.heightCm == null && !widget.who.isMember) ...[
            const SizedBox(height: 10),
            TextField(controller: _height, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.heightAsk), onChanged: (_) => setState(() {})),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
            child: Text(b != null && h != null ? s.bmiLine(b.toString(), h) : s.bmiNoHeight),
          ),
          if (l?.weightGoalKg != null) ...[
            const SizedBox(height: 6),
            Text(s.targetWeight(numText(l!.weightGoalKg!, s)), style: TextStyle(color: p.muted)),
          ],
        ]);
      case 'TEMPERATURE':
        form.addAll([
          bigField(_v, s.tempF),
          const SizedBox(height: 10),
          rangeNote(l?.feverAboveF != null ? s.feverLimit(numText(l!.feverAboveF!, s)) : s.noLimitYet),
        ]);
      case 'INSULIN':
        form.addAll([
          bigField(_v, s.howManyUnits),
          const SizedBox(height: 14),
          Text(s.whereInjected, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final site in injectionSites)
              PillButton(label: tr(injectionSiteNames[site]!, s.bn), selected: _site == site, onTap: () => setState(() => _site = site)),
          ]),
          const SizedBox(height: 10),
          NoteLine(s.onlyPrescribedUnits, icon: Icons.shield_outlined),
        ]);
      case 'SLEEP':
        form.add(_Stepper(
          title: s.sleepHoursQ,
          value: s.hoursValue(_hours == _hours.roundToDouble() ? _hours.toInt() : _hours),
          goal: l?.sleepHours == null ? null : s.goalHours(numText(l!.sleepHours!, s)),
          onMinus: _hours > 0 ? () => setState(() => _hours -= 0.5) : null,
          onPlus: _hours < 24 ? () => setState(() => _hours += 0.5) : null,
        ));
      case 'WATER':
        form.add(_Stepper(
          title: s.waterQ,
          value: s.glasses(_glasses),
          goal: l?.waterGlasses == null ? null : s.goalGlasses(l!.waterGlasses!),
          onMinus: _glasses > 0 ? () => setState(() => _glasses -= 1) : null,
          onPlus: _glasses < 40 ? () => setState(() => _glasses += 1) : null,
        ));
      case 'PEAK_FLOW':
        form.add(bigField(_v, s.peakFlowField));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.who.isMember ? '${s.logReading} · ${widget.who.memberName ?? ''}' : s.logReading)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            label: s.whatMeasured,
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in readingTypes)
                PillButton(label: readingTypeName(t, s), icon: readingIcon(t), selected: _type == t, onTap: () => _switchType(t)),
            ]),
          ),
          const SizedBox(height: 20),
          ...form,
          if (_type != 'WATER' && _type != 'SLEEP') ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                title: Text(s.time, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(s.n(_at.format(context)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _at);
                  if (t != null) setState(() => _at = t);
                },
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: p.later, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : () => _save(care), child: Text(s.save)),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.title, required this.value, this.goal, this.onMinus, this.onPlus});

  final String title;
  final String value;
  final String? goal;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SectionCard(title: title, children: [
      Row(children: [
        IconButton.outlined(onPressed: onMinus, icon: const Icon(Icons.remove)),
        Expanded(child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        IconButton.outlined(onPressed: onPlus, icon: const Icon(Icons.add)),
      ]),
      if (goal != null) ...[const SizedBox(height: 6), Text(goal!, textAlign: TextAlign.center, style: TextStyle(color: p.muted))],
    ]);
  }
}

// --- paths (also used by the other care screens) ---

Map<String, String> _whoQuery(CareSubject who) => {
      if (who.memberId != null) 'for': who.memberId!,
      if (who.memberName != null) 'name': who.memberName!,
    };

String readingPath(String? type, [CareSubject who = const CareSubject()]) =>
    Uri(path: '/health/reading', queryParameters: {'type': ?type, ..._whoQuery(who)}).toString();
String limitsPath([CareSubject who = const CareSubject()]) => Uri(path: '/health/limits', queryParameters: _whoQuery(who).isEmpty ? null : _whoQuery(who)).toString();
String conditionPath(String code, [CareSubject who = const CareSubject()]) =>
    Uri(path: '/health/care/$code', queryParameters: _whoQuery(who).isEmpty ? null : _whoQuery(who)).toString();
String myCarePath([CareSubject who = const CareSubject()]) => Uri(path: '/health/my-care', queryParameters: _whoQuery(who).isEmpty ? null : _whoQuery(who)).toString();
String insulinPath([CareSubject who = const CareSubject()]) => Uri(path: '/health/insulin', queryParameters: _whoQuery(who).isEmpty ? null : _whoQuery(who)).toString();
String recordsPath([CareSubject who = const CareSubject()]) => Uri(path: '/health/records', queryParameters: _whoQuery(who).isEmpty ? null : _whoQuery(who)).toString();
String testFormPath({String? id, String? kind, bool done = false, String? reminderId, String? condition, CareSubject who = const CareSubject()}) => Uri(
      path: '/health/records/test',
      queryParameters: {'id': ?id, 'kind': ?kind, if (done) 'done': '1', 'reminder': ?reminderId, 'condition': ?condition, ..._whoQuery(who)},
    ).toString();
String testReportPath(String id, [CareSubject who = const CareSubject()]) =>
    Uri(path: '/health/records/report/$id', queryParameters: _whoQuery(who).isEmpty ? null : _whoQuery(who)).toString();
String visitFormPath({String? id, String kind = 'VISIT', String? condition, CareSubject who = const CareSubject()}) => Uri(
      path: '/health/records/visit',
      queryParameters: {'id': ?id, 'kind': kind, 'condition': ?condition, ..._whoQuery(who)},
    ).toString();
String recordRxPath({String? id, CareSubject who = const CareSubject()}) =>
    Uri(path: '/health/records/rx', queryParameters: {'id': ?id, ..._whoQuery(who)}).toString();

CareSubject subjectFromQuery(Map<String, String> q) => CareSubject(memberId: q['for'], memberName: q['name']);
