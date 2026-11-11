/// Round 15-16 data: "My care" (GET /care) and Health records 2.0
/// (GET /records), plus the owner-edited condition and test lists from
/// GET /lookups. Kept as plain classes read from the server's JSON; the
/// repository caches the raw JSON so everything works offline.
library;

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
int? _i(Object? v) => v == null ? null : (v as num).toInt();
DateTime? _t(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

/// YYYY-MM-DD for a calendar date (local).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A YYYY-MM-DD string as a local calendar date (midnight).
DateTime parseDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ---------------------------------------------------------------------------
// Lookups (owner-edited, EN/BN)
// ---------------------------------------------------------------------------

class ConditionInfo {
  const ConditionInfo({required this.code, required this.nameEn, required this.nameBn, this.subtitleEn, this.subtitleBn});

  final String code;
  final String nameEn;
  final String nameBn;
  final String? subtitleEn;
  final String? subtitleBn;

  String name(bool bn) => bn ? nameBn : nameEn;
  String? subtitle(bool bn) => bn ? subtitleBn : subtitleEn;

  factory ConditionInfo.fromJson(Map<String, dynamic> j) => ConditionInfo(
        code: j['code'] as String,
        nameEn: j['nameEn'] as String,
        nameBn: j['nameBn'] as String,
        subtitleEn: j['subtitleEn'] as String?,
        subtitleBn: j['subtitleBn'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'code': code, 'nameEn': nameEn, 'nameBn': nameBn, 'subtitleEn': subtitleEn, 'subtitleBn': subtitleBn};
}

class TestKindField {
  const TestKindField({required this.id, required this.code, required this.nameEn, required this.nameBn, this.unit});

  final int id;
  final String code;
  final String nameEn;
  final String nameBn;
  final String? unit;

  String name(bool bn) => bn ? nameBn : nameEn;

  factory TestKindField.fromJson(Map<String, dynamic> j) => TestKindField(
        id: j['id'] as int,
        code: j['code'] as String,
        nameEn: j['nameEn'] as String,
        nameBn: j['nameBn'] as String,
        unit: j['unit'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'nameEn': nameEn, 'nameBn': nameBn, 'unit': unit};
}

class TestKind {
  const TestKind({required this.id, required this.code, required this.nameEn, required this.nameBn, this.diagnosticTestId, this.fields = const []});

  final int id;
  final String code;
  final String nameEn;
  final String nameBn;
  final String? diagnosticTestId;
  final List<TestKindField> fields;

  String name(bool bn) => bn ? nameBn : nameEn;

  factory TestKind.fromJson(Map<String, dynamic> j) => TestKind(
        id: j['id'] as int,
        code: j['code'] as String,
        nameEn: j['nameEn'] as String,
        nameBn: j['nameBn'] as String,
        diagnosticTestId: j['diagnosticTestId'] as String?,
        fields: [for (final f in (j['fields'] as List? ?? [])) TestKindField.fromJson(Map<String, dynamic>.from(f as Map))],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'nameEn': nameEn,
        'nameBn': nameBn,
        'diagnosticTestId': diagnosticTestId,
        'fields': [for (final f in fields) f.toJson()],
      };
}

class CareLookups {
  const CareLookups({this.conditions = const [], this.testKinds = const []});

  final List<ConditionInfo> conditions;
  final List<TestKind> testKinds;

  ConditionInfo? condition(String code) {
    for (final c in conditions) {
      if (c.code == code) return c;
    }
    return null;
  }

  TestKind? testKind(String? code) {
    if (code == null) return null;
    for (final k in testKinds) {
      if (k.code == code) return k;
    }
    return null;
  }

  factory CareLookups.fromJson(Map<String, dynamic> j) => CareLookups(
        conditions: [for (final c in (j['conditions'] as List? ?? [])) ConditionInfo.fromJson(Map<String, dynamic>.from(c as Map))],
        testKinds: [for (final k in (j['testKinds'] as List? ?? [])) TestKind.fromJson(Map<String, dynamic>.from(k as Map))],
      );

  Map<String, dynamic> toJson() => {
        'conditions': [for (final c in conditions) c.toJson()],
        'testKinds': [for (final k in testKinds) k.toJson()],
      };
}

// ---------------------------------------------------------------------------
// My care
// ---------------------------------------------------------------------------

enum SugarUnit { mmol, mgdl }

/// The doctor's numbers (sugar in mmol/L). Null = not set.
class HealthLimits {
  const HealthLimits({
    this.sugarUnit = SugarUnit.mmol,
    this.fastingLow,
    this.fastingHigh,
    this.afterFoodHigh,
    this.lowSugar,
    this.hba1cTarget,
    this.bpSystolicHigh,
    this.bpDiastolicHigh,
    this.bpSystolicLow,
    this.bpCrisisSystolic,
    this.bpCrisisDiastolic,
    this.peakFlowBest,
    this.weightGain3Days,
    this.tshLow,
    this.tshHigh,
    this.fluidLimitMl,
    this.feverAboveF,
    this.weightGoalKg,
    this.waterGlasses,
    this.sleepHours,
    this.notifyFamily = true,
    this.doctorNote,
    this.byCaregiver = false,
  });

  final SugarUnit sugarUnit;
  final double? fastingLow;
  final double? fastingHigh;
  final double? afterFoodHigh;
  final double? lowSugar;
  final double? hba1cTarget;
  final int? bpSystolicHigh;
  final int? bpDiastolicHigh;
  final int? bpSystolicLow;
  final int? bpCrisisSystolic;
  final int? bpCrisisDiastolic;
  final int? peakFlowBest;
  final double? weightGain3Days;
  final double? tshLow;
  final double? tshHigh;
  final int? fluidLimitMl;
  final double? feverAboveF;
  final double? weightGoalKg;
  final int? waterGlasses;
  final double? sleepHours;
  final bool notifyFamily;
  final String? doctorNote;
  final bool byCaregiver;

  static const none = HealthLimits();

  bool get hasSugar => fastingLow != null || fastingHigh != null || afterFoodHigh != null || lowSugar != null;
  bool get hasBp => bpSystolicHigh != null || bpDiastolicHigh != null || bpSystolicLow != null;
  bool get anySet => hasSugar || hasBp || hba1cTarget != null || feverAboveF != null || tshLow != null || tshHigh != null || peakFlowBest != null || weightGain3Days != null;

  factory HealthLimits.fromJson(Map<String, dynamic> j) => HealthLimits(
        sugarUnit: j['sugarUnit'] == 'MGDL' ? SugarUnit.mgdl : SugarUnit.mmol,
        fastingLow: _d(j['fastingLow']),
        fastingHigh: _d(j['fastingHigh']),
        afterFoodHigh: _d(j['afterFoodHigh']),
        lowSugar: _d(j['lowSugar']),
        hba1cTarget: _d(j['hba1cTarget']),
        bpSystolicHigh: _i(j['bpSystolicHigh']),
        bpDiastolicHigh: _i(j['bpDiastolicHigh']),
        bpSystolicLow: _i(j['bpSystolicLow']),
        bpCrisisSystolic: _i(j['bpCrisisSystolic']),
        bpCrisisDiastolic: _i(j['bpCrisisDiastolic']),
        peakFlowBest: _i(j['peakFlowBest']),
        weightGain3Days: _d(j['weightGain3Days']),
        tshLow: _d(j['tshLow']),
        tshHigh: _d(j['tshHigh']),
        fluidLimitMl: _i(j['fluidLimitMl']),
        feverAboveF: _d(j['feverAboveF']),
        weightGoalKg: _d(j['weightGoalKg']),
        waterGlasses: _i(j['waterGlasses']),
        sleepHours: _d(j['sleepHours']),
        notifyFamily: j['notifyFamily'] as bool? ?? true,
        doctorNote: j['doctorNote'] as String?,
        byCaregiver: j['byCaregiver'] as bool? ?? false,
      );

  /// The raw number of a limit by its API field name (for the limits form).
  Object? field(String key) => toJson()[key];

  Map<String, dynamic> toJson() => {
        'sugarUnit': sugarUnit == SugarUnit.mgdl ? 'MGDL' : 'MMOL',
        'fastingLow': fastingLow,
        'fastingHigh': fastingHigh,
        'afterFoodHigh': afterFoodHigh,
        'lowSugar': lowSugar,
        'hba1cTarget': hba1cTarget,
        'bpSystolicHigh': bpSystolicHigh,
        'bpDiastolicHigh': bpDiastolicHigh,
        'bpSystolicLow': bpSystolicLow,
        'bpCrisisSystolic': bpCrisisSystolic,
        'bpCrisisDiastolic': bpCrisisDiastolic,
        'peakFlowBest': peakFlowBest,
        'weightGain3Days': weightGain3Days,
        'tshLow': tshLow,
        'tshHigh': tshHigh,
        'fluidLimitMl': fluidLimitMl,
        'feverAboveF': feverAboveF,
        'weightGoalKg': weightGoalKg,
        'waterGlasses': waterGlasses,
        'sleepHours': sleepHours,
        'notifyFamily': notifyFamily,
        'doctorNote': doctorNote,
        'byCaregiver': byCaregiver,
      };
}

enum CareLogKind { symptoms, kicks, reliever, tdDose }

CareLogKind _logKind(String s) => switch (s) {
      'SYMPTOMS' => CareLogKind.symptoms,
      'KICKS' => CareLogKind.kicks,
      'RELIEVER' => CareLogKind.reliever,
      _ => CareLogKind.tdDose,
    };

String careLogKindApi(CareLogKind k) => switch (k) {
      CareLogKind.symptoms => 'SYMPTOMS',
      CareLogKind.kicks => 'KICKS',
      CareLogKind.reliever => 'RELIEVER',
      CareLogKind.tdDose => 'TD_DOSE',
    };

class CareLog {
  const CareLog({required this.id, required this.kind, this.conditionCode, required this.loggedAt, required this.data, this.byCaregiver = false});

  final String id;
  final CareLogKind kind;
  final String? conditionCode;
  final DateTime loggedAt;
  final Map<String, dynamic> data;
  final bool byCaregiver;

  List<String> get symptoms => [for (final s in (data['symptoms'] as List? ?? [])) s as String];
  bool get fine => data['fine'] == true;
  int get count => _i(data['count']) ?? 0;
  int get minutes => _i(data['minutes']) ?? 0;
  int get puffs => _i(data['puffs']) ?? 1;
  String? get date => data['date'] as String?;

  factory CareLog.fromJson(Map<String, dynamic> j) => CareLog(
        id: j['id'] as String,
        kind: _logKind(j['kind'] as String),
        conditionCode: j['conditionCode'] as String?,
        loggedAt: _t(j['loggedAt'])!,
        data: Map<String, dynamic>.from(j['data'] as Map? ?? {}),
        byCaregiver: j['byCaregiver'] as bool? ?? false,
      );
}

class DoctorQuestion {
  const DoctorQuestion({required this.id, required this.text, required this.createdAt, this.byCaregiver = false});

  final String id;
  final String text;
  final DateTime createdAt;
  final bool byCaregiver;

  factory DoctorQuestion.fromJson(Map<String, dynamic> j) => DoctorQuestion(
        id: j['id'] as String,
        text: j['text'] as String,
        createdAt: _t(j['createdAt'])!,
        byCaregiver: j['byCaregiver'] as bool? ?? false,
      );
}

/// GET /care: everything the condition pages need.
class CareOverview {
  const CareOverview({
    this.conditions = const [],
    this.careStepDone = false,
    this.heightCm,
    this.limits,
    this.settings = const {},
    this.ticks = const {},
    this.logs = const [],
    this.questions = const [],
  });

  final List<String> conditions;
  final bool careStepDone;
  final int? heightCm;
  final HealthLimits? limits;
  final Map<String, Map<String, dynamic>> settings;

  /// "key|YYYY-MM-DD" of every tick in the last 7 days.
  final Set<String> ticks;
  final List<CareLog> logs;
  final List<DoctorQuestion> questions;

  static const empty = CareOverview();

  HealthLimits get limitsOrNone => limits ?? HealthLimits.none;
  bool has(String code) => conditions.contains(code);
  Map<String, dynamic> setting(String code) => settings[code] ?? const {};
  bool ticked(String key, DateTime day) => ticks.contains('$key|${isoDate(day)}');

  factory CareOverview.fromJson(Map<String, dynamic> j) => CareOverview(
        conditions: [for (final c in (j['conditions'] as List? ?? [])) c as String],
        careStepDone: j['careStepDone'] as bool? ?? false,
        heightCm: _i(j['heightCm']),
        limits: j['limits'] == null ? null : HealthLimits.fromJson(Map<String, dynamic>.from(j['limits'] as Map)),
        settings: {
          for (final e in (Map<String, dynamic>.from(j['settings'] as Map? ?? {})).entries)
            e.key: Map<String, dynamic>.from(e.value as Map),
        },
        ticks: {
          for (final t in (j['ticks'] as List? ?? [])) '${(t as Map)['key']}|${t['day']}',
        },
        logs: [for (final l in (j['logs'] as List? ?? [])) CareLog.fromJson(Map<String, dynamic>.from(l as Map))],
        questions: [for (final q in (j['questions'] as List? ?? [])) DoctorQuestion.fromJson(Map<String, dynamic>.from(q as Map))],
      );
}

// ---------------------------------------------------------------------------
// Health records 2.0
// ---------------------------------------------------------------------------

/// A catalog doctor or one of the patient's own ("my doctors").
class DoctorRef {
  const DoctorRef({required this.id, required this.name, required this.mine, this.chamber, this.area, this.specialty});

  final String id;
  final String name;
  final bool mine;
  final String? chamber;
  final String? area;
  final String? specialty;

  String get line => [specialty, chamber, area].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  factory DoctorRef.fromJson(Map<String, dynamic> j, {bool? mine}) => DoctorRef(
        id: j['id'] as String,
        name: j['name'] as String,
        mine: mine ?? j['source'] == 'MINE',
        chamber: j['chamber'] as String?,
        area: (j['area'] ?? j['district']) as String?,
        specialty: j['specialty'] as String?,
      );
}

enum AppointmentKind { visit, anc, chemo }

class Appointment {
  const Appointment({
    required this.id,
    required this.kind,
    required this.date,
    this.time,
    this.doctor,
    this.conditionCode,
    this.number,
    this.note,
    this.remind = true,
    this.done = false,
    this.byCaregiver = false,
  });

  final String id;
  final AppointmentKind kind;
  final String date;
  final String? time;
  final DoctorRef? doctor;
  final String? conditionCode;
  final int? number;
  final String? note;
  final bool remind;
  final bool done;
  final bool byCaregiver;

  DateTime get day => parseDate(date);

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String,
        kind: switch (j['kind']) { 'ANC' => AppointmentKind.anc, 'CHEMO' => AppointmentKind.chemo, _ => AppointmentKind.visit },
        date: j['date'] as String,
        time: j['time'] as String?,
        doctor: j['doctor'] == null ? null : DoctorRef.fromJson(Map<String, dynamic>.from(j['doctor'] as Map)),
        conditionCode: j['conditionCode'] as String?,
        number: _i(j['number']),
        note: j['note'] as String?,
        remind: j['remind'] as bool? ?? true,
        done: j['done'] as bool? ?? false,
        byCaregiver: j['byCaregiver'] as bool? ?? false,
      );
}

class RecordPhoto {
  const RecordPhoto({required this.id, required this.page, required this.imageUrl});

  final String id;
  final int page;
  final String imageUrl;

  factory RecordPhoto.fromJson(Map<String, dynamic> j) =>
      RecordPhoto(id: j['id'] as String, page: _i(j['page']) ?? 1, imageUrl: j['imageUrl'] as String);
}

class TestValue {
  const TestValue({required this.name, this.fieldId, this.value, this.textValue, this.unit});

  final String name;
  final int? fieldId;
  final double? value;
  final String? textValue;
  final String? unit;

  factory TestValue.fromJson(Map<String, dynamic> j) => TestValue(
        name: j['name'] as String,
        fieldId: _i(j['fieldId']),
        value: _d(j['value']),
        textValue: j['textValue'] as String?,
        unit: j['unit'] as String?,
      );
}

class OwnTest {
  const OwnTest({
    required this.id,
    this.testKindCode,
    this.otherName,
    required this.done,
    required this.date,
    this.remind = true,
    this.fasting = false,
    this.findings,
    this.lab,
    this.conditionCode,
    this.healthReminderId,
    this.values = const [],
    this.photos = const [],
    this.byCaregiver = false,
  });

  final String id;
  final String? testKindCode;
  final String? otherName;
  final bool done;
  final String date;
  final bool remind;
  final bool fasting;
  final String? findings;
  final String? lab;
  final String? conditionCode;
  final String? healthReminderId;
  final List<TestValue> values;
  final List<RecordPhoto> photos;
  final bool byCaregiver;

  DateTime get day => parseDate(date);
  bool get hasNumbers => values.isNotEmpty;

  /// The value of the kind's field [fieldId] (e.g. creatinine), if recorded.
  double? valueOf(int fieldId) {
    for (final v in values) {
      if (v.fieldId == fieldId && v.value != null) return v.value;
    }
    return null;
  }

  factory OwnTest.fromJson(Map<String, dynamic> j) => OwnTest(
        id: j['id'] as String,
        testKindCode: j['testKindCode'] as String?,
        otherName: j['otherName'] as String?,
        done: j['status'] == 'DONE',
        date: j['date'] as String,
        remind: j['remind'] as bool? ?? true,
        fasting: j['fasting'] as bool? ?? false,
        findings: j['findings'] as String?,
        lab: j['lab'] as String?,
        conditionCode: j['conditionCode'] as String?,
        healthReminderId: j['healthReminderId'] as String?,
        values: [for (final v in (j['values'] as List? ?? [])) TestValue.fromJson(Map<String, dynamic>.from(v as Map))],
        photos: [for (final p in (j['photos'] as List? ?? [])) RecordPhoto.fromJson(Map<String, dynamic>.from(p as Map))],
        byCaregiver: j['byCaregiver'] as bool? ?? false,
      );
}

class RecordPrescription {
  const RecordPrescription({required this.id, required this.date, this.doctor, this.conditionCode, this.note, this.photos = const [], this.byCaregiver = false});

  final String id;
  final String date;
  final DoctorRef? doctor;
  final String? conditionCode;
  final String? note;
  final List<RecordPhoto> photos;
  final bool byCaregiver;

  factory RecordPrescription.fromJson(Map<String, dynamic> j) => RecordPrescription(
        id: j['id'] as String,
        date: j['date'] as String,
        doctor: j['doctor'] == null ? null : DoctorRef.fromJson(Map<String, dynamic>.from(j['doctor'] as Map)),
        conditionCode: j['conditionCode'] as String?,
        note: j['note'] as String?,
        photos: [for (final p in (j['photos'] as List? ?? [])) RecordPhoto.fromJson(Map<String, dynamic>.from(p as Map))],
        byCaregiver: j['byCaregiver'] as bool? ?? false,
      );
}

/// GET /records.
class RecordsOverview {
  const RecordsOverview({this.myDoctors = const [], this.appointments = const [], this.tests = const [], this.prescriptions = const []});

  final List<DoctorRef> myDoctors;
  final List<Appointment> appointments;
  final List<OwnTest> tests;
  final List<RecordPrescription> prescriptions;

  static const empty = RecordsOverview();

  List<OwnTest> get upcomingTests => tests.where((t) => !t.done).toList()..sort((a, b) => a.date.compareTo(b.date));
  List<OwnTest> get results => tests.where((t) => t.done).toList()..sort((a, b) => b.date.compareTo(a.date));

  /// Results of one test kind, oldest first (graphs, earlier results).
  List<OwnTest> resultsOf(String kindCode) =>
      tests.where((t) => t.done && t.testKindCode == kindCode).toList()..sort((a, b) => a.date.compareTo(b.date));

  factory RecordsOverview.fromJson(Map<String, dynamic> j) => RecordsOverview(
        myDoctors: [for (final d in (j['myDoctors'] as List? ?? [])) DoctorRef.fromJson(Map<String, dynamic>.from(d as Map), mine: true)],
        appointments: [for (final a in (j['appointments'] as List? ?? [])) Appointment.fromJson(Map<String, dynamic>.from(a as Map))],
        tests: [for (final t in (j['tests'] as List? ?? [])) OwnTest.fromJson(Map<String, dynamic>.from(t as Map))],
        prescriptions: [for (final p in (j['prescriptions'] as List? ?? [])) RecordPrescription.fromJson(Map<String, dynamic>.from(p as Map))],
      );
}
