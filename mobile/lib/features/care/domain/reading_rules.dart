/// Round 15 reading rules (owner, 2026-11-11), the same as the server's
/// backend/src/health/lib/reading-range.ts so a reading is judged offline.
///
/// - Range: only against the limits the user or caregiver saved; a kind
///   with no saved limit has no range (no chip, no family alert).
/// - Crisis: fixed safety levels, limits or not: BP 180/120 or higher
///   (160/110 at most in pregnancy; the user may change the BP level),
///   sugar below 3.0 mmol/L (fixed).
library;

import 'care_models.dart';

const mgPerMmol = 18.0;
const sugarCrisisBelowMmol = 3.0;
const bpCrisisDefault = (systolic: 180, diastolic: 120);
const bpCrisisPregnancyMax = (systolic: 160, diastolic: 110);

enum RangeState { inRange, below, above }

RangeState? rangeStateFromApi(String? s) => switch (s) {
      'IN_RANGE' => RangeState.inRange,
      'BELOW' => RangeState.below,
      'ABOVE' => RangeState.above,
      _ => null,
    };

/// The four "when did you check" choices (API values).
const sugarContexts = ['FASTING', 'AFTER_FOOD', 'BEFORE_BED', 'RANDOM'];

double toMmol(double v, SugarUnit unit) => unit == SugarUnit.mgdl ? v / mgPerMmol : v;
double fromMmol(double mmol, SugarUnit unit) => unit == SugarUnit.mgdl ? mmol * mgPerMmol : mmol;

/// Sugar as shown: mg/dL whole numbers, mmol/L one decimal.
String sugarText(double mmol, SugarUnit unit) =>
    unit == SugarUnit.mgdl ? (mmol * mgPerMmol).round().toString() : mmol.toStringAsFixed(1);

String sugarUnitText(SugarUnit unit) => unit == SugarUnit.mgdl ? 'mg/dL' : 'mmol/L';

({int systolic, int diastolic}) bpCrisisLevel(HealthLimits? limits, {required bool pregnant}) {
  var s = limits?.bpCrisisSystolic ?? bpCrisisDefault.systolic;
  var d = limits?.bpCrisisDiastolic ?? bpCrisisDefault.diastolic;
  if (pregnant) {
    if (s > bpCrisisPregnancyMax.systolic) s = bpCrisisPregnancyMax.systolic;
    if (d > bpCrisisPregnancyMax.diastolic) d = bpCrisisPregnancyMax.diastolic;
  }
  return (systolic: s, diastolic: d);
}

bool isBpCrisis(int systolic, int diastolic, HealthLimits? limits, {required bool pregnant}) {
  final level = bpCrisisLevel(limits, pregnant: pregnant);
  return systolic >= level.systolic || diastolic >= level.diastolic;
}

bool isSugarCrisis(double mmol) => mmol < sugarCrisisBelowMmol;

RangeState? bpRange(int systolic, int diastolic, HealthLimits? l) {
  if (l == null || !l.hasBp) return null;
  if (l.bpSystolicLow != null && systolic < l.bpSystolicLow!) return RangeState.below;
  if ((l.bpSystolicHigh != null && systolic >= l.bpSystolicHigh!) || (l.bpDiastolicHigh != null && diastolic >= l.bpDiastolicHigh!)) {
    return RangeState.above;
  }
  return RangeState.inRange;
}

RangeState? sugarRange(double mmol, String? context, HealthLimits? l) {
  if (l == null) return null;
  final fasting = context == 'FASTING';
  final low = fasting ? (l.fastingLow ?? l.lowSugar) : l.lowSugar;
  final high = fasting ? l.fastingHigh : l.afterFoodHigh;
  if (low == null && high == null && l.lowSugar == null) return null;
  if (l.lowSugar != null && mmol < l.lowSugar!) return RangeState.below;
  if (low != null && mmol < low) return RangeState.below;
  if (high != null && mmol > high) return RangeState.above;
  return RangeState.inRange;
}

RangeState? feverRange(double f, HealthLimits? l) {
  if (l?.feverAboveF == null) return null;
  return f > l!.feverAboveF! ? RangeState.above : RangeState.inRange;
}

RangeState? tshRange(double v, HealthLimits? l) {
  if (l == null || (l.tshLow == null && l.tshHigh == null)) return null;
  if (l.tshLow != null && v < l.tshLow!) return RangeState.below;
  if (l.tshHigh != null && v > l.tshHigh!) return RangeState.above;
  return RangeState.inRange;
}

/// BMI from kg and cm, one decimal; null without a height.
double? bmi(double kg, int? heightCm) {
  if (heightCm == null || heightCm <= 0) return null;
  final m = heightCm / 100;
  return double.parse((kg / (m * m)).toStringAsFixed(1));
}

/// The average of one or two BP measurements (as doctors prefer).
({int systolic, int diastolic, int measurements}) bpAverage(int s1, int d1, int? s2, int? d2) {
  if (s2 == null || d2 == null) return (systolic: s1, diastolic: d1, measurements: 1);
  return (systolic: ((s1 + s2) / 2).round(), diastolic: ((d1 + d2) / 2).round(), measurements: 2);
}

// --- Insulin sites -----------------------------------------------------------

/// Rotation order of the body map (the body faces the viewer).
const injectionSites = ['LEFT_THIGH', 'RIGHT_THIGH', 'LEFT_ABDOMEN', 'RIGHT_ABDOMEN', 'LEFT_ARM', 'RIGHT_ARM'];

/// The suggested next site: the one used longest ago (never used first),
/// never one used today. [lastUsed] = site -> last time it was used.
String suggestedSite(Map<String, DateTime> lastUsed, DateTime now) {
  final today = dateOnly(now);
  String? best;
  DateTime? bestAt;
  for (final site in injectionSites) {
    final at = lastUsed[site];
    if (at != null && !dateOnly(at).isBefore(today)) continue;
    if (at == null) return site;
    if (bestAt == null || at.isBefore(bestAt)) {
      best = site;
      bestAt = at;
    }
  }
  return best ?? injectionSites.first;
}

/// Pen "use by" after opening, and whether to warn now.
({DateTime useBy, int daysLeft, bool warn}) penStatus(DateTime openedOn, int lifeDays, int remindDaysBefore, DateTime now) {
  final useBy = dateOnly(openedOn).add(Duration(days: lifeDays));
  final daysLeft = useBy.difference(dateOnly(now)).inDays;
  return (useBy: useBy, daysLeft: daysLeft, warn: daysLeft <= remindDaysBefore);
}

// --- Asthma ------------------------------------------------------------------

enum PeakFlowZone { green, yellow, red }

/// Green 80% of the best or more, yellow 50-79%, red below 50%.
({PeakFlowZone zone, int percent})? peakFlowZone(double value, int? best) {
  if (best == null || best <= 0) return null;
  final pct = (value / best * 100).round();
  final zone = pct >= 80 ? PeakFlowZone.green : pct >= 50 ? PeakFlowZone.yellow : PeakFlowZone.red;
  return (zone: zone, percent: pct);
}

/// Days in the last 7 (today included) with at least one reliever puff.
int relieverDays(Iterable<CareLog> logs, DateTime now) {
  final from = dateOnly(now).subtract(const Duration(days: 6));
  return logs
      .where((l) => l.kind == CareLogKind.reliever && !dateOnly(l.loggedAt).isBefore(from))
      .map((l) => isoDate(l.loggedAt))
      .toSet()
      .length;
}

// --- Pregnancy ----------------------------------------------------------------

/// Weeks and days from the due date (40 weeks = 280 days), and the trimester.
({int weeks, int days, int trimester, int weeksLeft})? gestation(DateTime? dueDate, DateTime now) {
  if (dueDate == null) return null;
  final left = dateOnly(dueDate).difference(dateOnly(now)).inDays;
  final along = 280 - left;
  if (along < 0) return null;
  final weeks = along ~/ 7;
  return (
    weeks: weeks,
    days: along % 7,
    trimester: weeks < 14 ? 1 : weeks < 28 ? 2 : 3,
    weeksLeft: left <= 0 ? 0 : (left / 7).ceil(),
  );
}

// --- Heart: weight gain -------------------------------------------------------

/// Weight change between the latest weight and the latest one at least 3
/// days before it; null without both. [weights] = (when, kg).
double? weightGain3Days(List<(DateTime, double)> weights) {
  if (weights.isEmpty) return null;
  final sorted = [...weights]..sort((a, b) => a.$1.compareTo(b.$1));
  final last = sorted.last;
  final cutoff = dateOnly(last.$1).subtract(const Duration(days: 3));
  (DateTime, double)? before;
  for (final w in sorted) {
    if (!dateOnly(w.$1).isAfter(cutoff)) before = w;
  }
  if (before == null) return null;
  return double.parse((last.$2 - before.$2).toStringAsFixed(1));
}

// --- Regular tests --------------------------------------------------------------

DateTime addMonths(DateTime d, int months) {
  final y = d.year + (d.month - 1 + months) ~/ 12;
  final m = (d.month - 1 + months) % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}

/// When a regular test is next due: the last result plus how often (months).
DateTime? testDue(DateTime? lastDone, int everyMonths) =>
    lastDone == null || everyMonths <= 0 ? null : addMonths(lastDone, everyMonths);

/// The last 7 days, oldest first, each 1 (done), 0 (not) or null (unknown).
List<int?> sevenDayDots(bool Function(DateTime day) done, DateTime now) => [
      for (var i = 6; i >= 0; i--) done(dateOnly(now).subtract(Duration(days: i))) ? 1 : 0,
    ];
