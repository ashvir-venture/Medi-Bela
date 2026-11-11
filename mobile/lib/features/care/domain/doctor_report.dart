import '../../health/domain/health_models.dart';
import '../../medicine_schedule/domain/dose_display_status.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';
import 'care_content.dart';
import 'care_models.dart';
import 'reading_rules.dart';

/// What the doctor's PDF shows (Round 16 E): the last [days] days of doses
/// split into on time / late / missed per medicine, readings (BP, sugar,
/// weight, temperature, insulin), the limits, test results with values,
/// the questions for the doctor, and the report photos to attach.
class DoctorReport {
  DoctorReport({
    required this.patientName,
    required this.from,
    required this.to,
    required this.conditions,
    required this.medicines,
    required this.bp,
    required this.sugar,
    required this.weights,
    required this.temperatures,
    required this.insulin,
    required this.limitLines,
    required this.results,
    required this.questions,
    required this.photos,
  });

  final String patientName;
  final DateTime from;
  final DateTime to;
  final List<String> conditions;
  final List<MedicineAdherence> medicines;
  final List<HealthRecordModel> bp;
  final List<HealthRecordModel> sugar;
  final List<HealthRecordModel> weights;
  final List<HealthRecordModel> temperatures;
  final List<HealthRecordModel> insulin;
  final List<String> limitLines;
  final List<OwnTest> results;
  final List<String> questions;

  /// (caption, signed link) of each report page photo.
  final List<(String, String)> photos;

  int get onTime => medicines.fold(0, (a, m) => a + m.onTime);
  int get late => medicines.fold(0, (a, m) => a + m.late);
  int get missed => medicines.fold(0, (a, m) => a + m.missed);

  ({int systolic, int diastolic})? get bpAverage {
    final xs = bp.where((r) => r.systolic != null && r.diastolic != null).toList();
    if (xs.isEmpty) return null;
    return (
      systolic: (xs.map((r) => r.systolic!).reduce((a, b) => a + b) / xs.length).round(),
      diastolic: (xs.map((r) => r.diastolic!).reduce((a, b) => a + b) / xs.length).round(),
    );
  }

  /// The average sugar (mmol/L) of one "when checked" context.
  double? sugarAverage(String context) {
    final xs = sugar.where((r) => r.sugarContext == context && r.numericValue != null).map((r) => r.numericValue!).toList();
    if (xs.isEmpty) return null;
    return xs.reduce((a, b) => a + b) / xs.length;
  }
}

class MedicineAdherence {
  MedicineAdherence(this.name, this.dosage);

  final String name;
  final String dosage;
  int onTime = 0;
  int late = 0;
  int missed = 0;

  int get total => onTime + late + missed;
}

/// Puts the report together from the cached data (pure; tested).
DoctorReport buildDoctorReport({
  required String patientName,
  required DateTime now,
  int days = 30,
  required List<MedicineDoseModel> doses,
  required List<HealthRecordModel> readings,
  required CareOverview care,
  required RecordsOverview records,
  required CareLookups? lookups,
  int? graceMinutes,
}) {
  final to = now;
  final from = dateOnly(now).subtract(Duration(days: days - 1));
  bool inPeriod(DateTime t) => !t.isBefore(from) && !t.isAfter(to);

  final byMedicine = <String, MedicineAdherence>{};
  for (final d in doses) {
    if (!inPeriod(d.scheduledAt.toLocal())) continue;
    final outcome = doseOutcome(d, graceMinutes: graceMinutes);
    if (outcome == null) continue;
    final m = byMedicine.putIfAbsent(d.routineId, () => MedicineAdherence(d.medicineName, d.dosage));
    switch (outcome) {
      case DoseOutcome.onTime:
        m.onTime++;
      case DoseOutcome.late:
        m.late++;
      case DoseOutcome.missed:
        m.missed++;
    }
  }

  List<HealthRecordModel> of(String type) =>
      readings.where((r) => r.type == type && inPeriod(r.recordedAt.toLocal())).toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  final l = care.limits;
  final unit = care.limitsOrNone.sugarUnit;
  String sugar(double mmol) => '${sugarText(mmol, unit)} ${sugarUnitText(unit)}';
  final limitLines = <String>[
    if (l?.fastingLow != null || l?.fastingHigh != null)
      'Fasting sugar ${l?.fastingLow == null ? '-' : sugar(l!.fastingLow!)} to ${l?.fastingHigh == null ? '-' : sugar(l!.fastingHigh!)}',
    if (l?.afterFoodHigh != null) '2 h after food up to ${sugar(l!.afterFoodHigh!)}',
    if (l?.lowSugar != null) 'Low sugar alert below ${sugar(l!.lowSugar!)}',
    if (l?.hba1cTarget != null) 'HbA1c below ${l!.hba1cTarget}%',
    if (l?.bpSystolicHigh != null || l?.bpDiastolicHigh != null) 'BP below ${l?.bpSystolicHigh ?? '-'}/${l?.bpDiastolicHigh ?? '-'} mmHg',
    if (l?.tshLow != null && l?.tshHigh != null) 'TSH ${l!.tshLow} to ${l.tshHigh} mIU/L',
    if (l?.doctorNote != null) 'Set by: ${l!.doctorNote}',
  ];

  String testLabel(OwnTest t) => lookups?.testKind(t.testKindCode)?.nameEn ?? t.otherName ?? t.testKindCode ?? 'Test';
  final results = records.results.where((t) => !t.day.isBefore(from.subtract(const Duration(days: 335)))).toList();
  final photos = <(String, String)>[
    for (final t in results)
      for (final ph in t.photos) ('${testLabel(t)}, ${isoDate(t.day)}, page ${ph.page}', ph.imageUrl),
  ];

  return DoctorReport(
    patientName: patientName,
    from: from,
    to: to,
    conditions: [for (final c in care.conditions) lookups?.condition(c)?.nameEn ?? conditionFallbackNames[c]?.$1 ?? c],
    medicines: byMedicine.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
    bp: of('BLOOD_PRESSURE'),
    sugar: of('BLOOD_SUGAR'),
    weights: of('WEIGHT'),
    temperatures: of('TEMPERATURE'),
    insulin: of('INSULIN'),
    limitLines: limitLines,
    results: results,
    questions: [for (final q in care.questions) q.text],
    photos: photos,
  );
}
