import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/care/data/care_reminders.dart';
import 'package:mobile/features/care/domain/care_models.dart';
import 'package:mobile/features/care/domain/doctor_report.dart';
import 'package:mobile/features/care/domain/reading_rules.dart';
import 'package:mobile/features/health/domain/health_models.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';

const doctor = HealthLimits(
  fastingLow: 4.4,
  fastingHigh: 7.0,
  afterFoodHigh: 10.0,
  lowSugar: 3.9,
  bpSystolicHigh: 140,
  bpDiastolicHigh: 90,
  bpSystolicLow: 90,
  feverAboveF: 100.4,
  tshLow: 0.4,
  tshHigh: 4.0,
);

void main() {
  group('reading rules (owner, 2026-11-11; same as the server)', () {
    test('no saved limit = no range', () {
      expect(bpRange(190, 125, null), isNull);
      expect(bpRange(190, 125, HealthLimits.none), isNull);
      expect(sugarRange(2.0, 'FASTING', HealthLimits.none), isNull);
      expect(feverRange(103, HealthLimits.none), isNull);
      expect(tshRange(9, HealthLimits.none), isNull);
    });

    test('BP, sugar by context, fever and TSH against the saved numbers', () {
      expect(bpRange(130, 85, doctor), RangeState.inRange);
      expect(bpRange(140, 80, doctor), RangeState.above);
      expect(bpRange(85, 60, doctor), RangeState.below);
      expect(sugarRange(6.5, 'FASTING', doctor), RangeState.inRange);
      expect(sugarRange(7.5, 'FASTING', doctor), RangeState.above);
      expect(sugarRange(4.2, 'FASTING', doctor), RangeState.below);
      expect(sugarRange(9.5, 'AFTER_FOOD', doctor), RangeState.inRange);
      expect(sugarRange(10.5, 'RANDOM', doctor), RangeState.above);
      expect(feverRange(101, doctor), RangeState.above);
      expect(tshRange(5, doctor), RangeState.above);
      expect(tshRange(2, doctor), RangeState.inRange);
    });

    test('crisis at fixed levels without limits; 160/110 at most in pregnancy; the user BP level', () {
      expect(isBpCrisis(180, 100, null, pregnant: false), isTrue);
      expect(isBpCrisis(170, 120, null, pregnant: false), isTrue);
      expect(isBpCrisis(179, 119, null, pregnant: false), isFalse);
      expect(isBpCrisis(162, 90, null, pregnant: true), isTrue);
      expect(bpCrisisLevel(const HealthLimits(bpCrisisSystolic: 170, bpCrisisDiastolic: 115), pregnant: false), (systolic: 170, diastolic: 115));
      expect(bpCrisisLevel(const HealthLimits(bpCrisisSystolic: 200, bpCrisisDiastolic: 130), pregnant: true), (systolic: 160, diastolic: 110));
      expect(isSugarCrisis(2.9), isTrue);
      expect(isSugarCrisis(3.0), isFalse);
    });

    test('units, average of two BP measurements, BMI', () {
      expect(sugarText(7.0, SugarUnit.mgdl), '126');
      expect(sugarText(7.0, SugarUnit.mmol), '7.0');
      expect(toMmol(126, SugarUnit.mgdl), closeTo(7.0, 0.001));
      expect(bpAverage(150, 95, 140, 90), (systolic: 145, diastolic: 93, measurements: 2));
      expect(bpAverage(150, 95, null, null), (systolic: 150, diastolic: 95, measurements: 1));
      expect(bmi(70, 170), 24.2);
      expect(bmi(70, null), isNull);
    });

    test('insulin: the site used longest ago, never one used today', () {
      final now = DateTime(2026, 11, 11, 9);
      expect(suggestedSite({}, now), 'LEFT_THIGH');
      final used = {
        for (final s in injectionSites) s: now.subtract(const Duration(days: 2)),
        'RIGHT_ARM': now.subtract(const Duration(days: 5)),
        'LEFT_THIGH': now.subtract(const Duration(hours: 1)),
      };
      expect(suggestedSite(used, now), 'RIGHT_ARM');
      final p = penStatus(DateTime(2026, 10, 20), 28, 3, now);
      expect(p.useBy, DateTime(2026, 11, 17));
      expect(p.daysLeft, 6);
      expect(p.warn, isFalse);
      expect(penStatus(DateTime(2026, 10, 20), 28, 7, now).warn, isTrue);
    });

    test('peak flow zones, reliever days, pregnancy weeks, 3-day weight gain, test due', () {
      expect(peakFlowZone(400, 400)!.zone, PeakFlowZone.green);
      expect(peakFlowZone(250, 400)!.zone, PeakFlowZone.yellow);
      expect(peakFlowZone(150, 400)!.zone, PeakFlowZone.red);
      expect(peakFlowZone(150, null), isNull);
      final now = DateTime(2026, 11, 11, 12);
      CareLog puff(DateTime at) => CareLog(id: '$at', kind: CareLogKind.reliever, loggedAt: at, data: const {});
      expect(relieverDays([puff(now), puff(now.subtract(const Duration(hours: 1))), puff(now.subtract(const Duration(days: 3))), puff(now.subtract(const Duration(days: 9)))], now), 2);
      final g = gestation(DateTime(2027, 3, 1), now)!;
      expect((g.weeks, g.trimester), (24, 2));
      expect(weightGain3Days([(DateTime(2026, 11, 7), 70.0), (DateTime(2026, 11, 8), 70.5), (DateTime(2026, 11, 11), 72.5)]), 2.0);
      expect(weightGain3Days([(DateTime(2026, 11, 11), 72.5)]), isNull);
      expect(testDue(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(testDue(DateTime(2026, 8, 31), 0), isNull);
    });
  });

  group('care reminders planner', () {
    final now = DateTime(2026, 11, 11, 10);
    final records = RecordsOverview.fromJson({
      'appointments': [
        {'id': 'v1', 'kind': 'VISIT', 'date': '2026-11-14', 'time': '17:00', 'remind': true},
        {'id': 'v2', 'kind': 'ANC', 'date': '2026-11-20', 'remind': true, 'number': 3},
        {'id': 'v3', 'kind': 'VISIT', 'date': '2026-11-15', 'remind': false},
        {'id': 'v4', 'kind': 'VISIT', 'date': '2026-11-16', 'remind': true, 'done': true},
      ],
      'tests': [
        {'id': 't1', 'testKindCode': 'hba1c', 'status': 'UPCOMING', 'date': '2026-11-13', 'remind': true, 'fasting': true},
        {'id': 't2', 'testKindCode': 'tsh', 'status': 'DONE', 'date': '2026-11-01'},
      ],
    });
    final care = CareOverview.fromJson({
      'conditions': ['kidney', 'diabetes'],
      'settings': {
        'kidney': {'dialysis': true, 'dialysisDays': [1, 4], 'dialysisTime': '09:00'},
        'diabetes': {
          'pen': {'openedOn': '2026-11-01', 'lifeDays': 28, 'remindDaysBefore': 3},
        },
      },
    });

    test('visits the day before at 19:00, tests at 09:00, nothing for done or switched off', () {
      final items = planCareReminders(care, records, enStrings.r15, now);
      final visit = items.firstWhere((i) => i.key == 'appt:v1');
      expect(visit.at, DateTime(2026, 11, 13, 19));
      expect(visit.title, enStrings.r15.remVisitTitle);
      expect(visit.body, isNot(contains('Dr')));
      expect(items.firstWhere((i) => i.key == 'appt:v2').title, enStrings.r15.remCheckupTitle);
      final test = items.firstWhere((i) => i.key == 'test:t1');
      expect(test.at, DateTime(2026, 11, 12, 9));
      expect(test.body, enStrings.r15.remTestBody(true));
      expect(items.any((i) => i.key == 'appt:v3' || i.key == 'appt:v4' || i.key == 'test:t2'), isFalse);
    });

    test('dialysis an hour before each chosen weekday, the pen before it expires, in Bengali too', () {
      final items = planCareReminders(care, records, bnStrings.r15, now);
      final dialysis = items.where((i) => i.key.startsWith('dialysis:')).toList();
      // Mondays and Thursdays in the next 14 days from Wed 11 Nov: 12, 16, 19, 23 Nov.
      expect(dialysis.map((i) => i.at), [DateTime(2026, 11, 12, 8), DateTime(2026, 11, 16, 8), DateTime(2026, 11, 19, 8), DateTime(2026, 11, 23, 8)]);
      expect(items.firstWhere((i) => i.key.startsWith('pen:')).at, DateTime(2026, 11, 26, 9));
      expect(items.first.title, isNot(equals(enStrings.r15.remTestTitle)));
      expect(items.every((i) => i.at.isAfter(now)), isTrue);
    });
  });

  test('the doctor report splits doses into on time / late / missed per medicine', () {
    final now = DateTime(2026, 11, 11, 20);
    MedicineDoseModel d(String id, String routine, DateTime at, String status, [DateTime? takenAt]) =>
        MedicineDoseModel(id: id, routineId: routine, medicineName: 'Med $routine', dosage: '1', scheduledAt: at, status: status, takenAt: takenAt);
    final at = DateTime(2026, 11, 10, 8);
    final report = buildDoctorReport(
      patientName: 'Abba',
      now: now,
      graceMinutes: 50,
      doses: [
        d('1', 'a', at, 'TAKEN', at.add(const Duration(minutes: 10))),
        d('2', 'a', at.add(const Duration(days: -1)), 'TAKEN', at.add(const Duration(days: -1, minutes: 90))),
        d('3', 'b', at, 'MISSED'),
        d('4', 'b', now.add(const Duration(hours: 2)), 'PENDING'),
        d('5', 'b', DateTime(2026, 9, 1), 'MISSED'), // before the 30 days
      ],
      readings: [
        HealthRecordModel(id: 'r1', type: 'BLOOD_PRESSURE', value: '150/90', recordedAt: at, syncState: 'synced', details: const {'systolic': 150, 'diastolic': 90}),
        HealthRecordModel(id: 'r2', type: 'BLOOD_PRESSURE', value: '130/80', recordedAt: at, syncState: 'synced'),
      ],
      care: CareOverview.empty,
      records: RecordsOverview.empty,
      lookups: null,
    );
    expect((report.onTime, report.late, report.missed), (1, 1, 1));
    expect(report.medicines.map((m) => (m.name, m.total)), [('Med a', 2), ('Med b', 1)]);
    expect(report.bpAverage, (systolic: 140, diastolic: 85));
  });

  test('my care overview reads ticks, logs and limits', () {
    final o = CareOverview.fromJson({
      'conditions': ['bp'],
      'careStepDone': true,
      'heightCm': 165,
      'limits': {'sugarUnit': 'MGDL', 'bpSystolicHigh': 140, 'notifyFamily': false},
      'ticks': [
        {'key': 'habit:walk', 'day': '2026-11-11'},
      ],
      'logs': [
        {'id': 'l1', 'kind': 'KICKS', 'loggedAt': '2026-11-11T05:00:00.000Z', 'data': {'count': 10, 'minutes': 25}},
      ],
      'questions': [],
    });
    expect(o.ticked('habit:walk', DateTime(2026, 11, 11, 18)), isTrue);
    expect(o.ticked('habit:walk', DateTime(2026, 11, 10)), isFalse);
    expect(o.limits!.sugarUnit, SugarUnit.mgdl);
    expect(o.limits!.hasBp, isTrue);
    expect(o.limits!.notifyFamily, isFalse);
    expect(o.logs.single.count, 10);
  });
}
