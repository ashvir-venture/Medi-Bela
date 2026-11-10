import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/text_size_controller.dart';
import 'package:mobile/core/utils/error_mapper.dart';
import 'package:mobile/features/home/domain/day_slots.dart';
import 'package:mobile/features/medicine_schedule/domain/dose_display_status.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'package:mobile/features/reminders/presentation/reminder_rules_screen.dart';
import 'package:mobile/notifications/reminder_timing.dart';
import 'package:dio/dio.dart';

MedicineDoseModel dose(String id, DateTime at, {String status = 'PENDING', DateTime? takenAt}) => MedicineDoseModel(
      id: id,
      routineId: 'r-$id',
      medicineName: 'Napa $id',
      dosage: '1 tablet',
      scheduledAt: at,
      status: status,
      takenAt: takenAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => ReminderTiming.current = const ReminderTiming());

  // Owner, 2026-11-10: On time = taken before the family-alert time; Late = after; Missed = never.
  group('On time / Late / Missed', () {
    final at = DateTime(2026, 11, 10, 8);

    test('taken before the family-alert time (50 min) is on time, after it late', () {
      expect(doseOutcome(dose('a', at, status: 'TAKEN', takenAt: at.add(const Duration(minutes: 50)))),
          DoseOutcome.onTime);
      expect(doseOutcome(dose('a', at, status: 'TAKEN', takenAt: at.add(const Duration(minutes: 51)))),
          DoseOutcome.late);
    });

    test("the user's own family-alert time moves the line", () {
      ReminderTiming.current = const ReminderTiming(missedGraceMinutes: 90);
      expect(doseOutcome(dose('a', at, status: 'TAKEN', takenAt: at.add(const Duration(minutes: 80)))),
          DoseOutcome.onTime);
    });

    test('missed is missed; open doses have no outcome yet', () {
      expect(doseOutcome(dose('a', at, status: 'MISSED')), DoseOutcome.missed);
      expect(doseOutcome(dose('a', at)), isNull);
    });
  });

  group("Home's three times of day", () {
    final day = DateTime(2026, 11, 10);
    DateTime t(int h, [int m = 0]) => day.add(Duration(hours: h, minutes: m));

    test('morning before 12, afternoon before 17, night after', () {
      expect(slotOf(t(8)), DaySlot.morning);
      expect(slotOf(t(14)), DaySlot.noon);
      expect(slotOf(t(21)), DaySlot.night);
    });

    test('now within one ring gap, late after it, later before, done when nothing is open', () {
      final eight = [dose('a', t(8))];
      expect(slotState(eight, t(7, 59)), SlotState.later);
      expect(slotState(eight, t(8, 10)), SlotState.now);
      expect(slotState(eight, t(8, 16)), SlotState.late);
      expect(slotState([dose('a', t(8), status: 'TAKEN')], t(9)), SlotState.done);
      expect(slotState(const [], t(9)), SlotState.none);
    });

    test('the next time is the one due first, else the next to come, else none', () {
      final today = [
        dose('m', t(8), status: 'TAKEN'),
        dose('n', t(14)),
        dose('x', t(21)),
      ];
      expect(nextSlot(daySlots(today, t(14, 5)))!.slot, DaySlot.noon);
      expect(nextSlot(daySlots(today, t(10)))!.slot, DaySlot.noon);
      final allDone = [dose('m', t(8), status: 'TAKEN'), dose('n', t(14), status: 'MISSED')];
      expect(nextSlot(daySlots(allDone, t(15))), isNull);
      expect(daySlots(allDone, t(15))[1].missed, 1);
    });

    test('Later from Home uses the current ring, never past the last', () {
      final at = t(8);
      expect(currentStage(at, t(8, 5)), 0);
      expect(currentStage(at, t(8, 31)), 2);
      expect(currentStage(at, t(10)), 3);
    });
  });

  group('own reminder timings', () {
    test('the server answer carries the Later delay and family-alert time', () {
      final t = ReminderTiming.fromJson({'repeatMinutes': 10, 'laterMinutes': 20, 'missedGraceMinutes': 40});
      expect([t.repeatMinutes, t.laterMinutes, t.missedGraceMinutes], [10, 20, 40]);
      // An older server without laterMinutes: Later follows the ring gap.
      expect(ReminderTiming.fromJson({'repeatMinutes': 10}).laterMinutes, 10);
    });

    test('the last ring ends at (rings - 1) x gap + ring time', () {
      expect(lastRingEnds(rings: 4, repeatMinutes: 15, ringMinutes: 2), 47);
      expect(lastRingEnds(rings: 3, repeatMinutes: 10, ringMinutes: 2), 22);
    });

    test('a refused save explains itself in both languages', () {
      final e = DioException(
        requestOptions: RequestOptions(),
        response: Response(
          requestOptions: RequestOptions(),
          statusCode: 400,
          data: {'code': 'FAMILY_ALERT_TOO_EARLY'},
        ),
      );
      expect(friendlyErrorMessage(e, enStrings), enStrings.r14.familyAlertTooEarly);
      expect(friendlyErrorMessage(e, bnStrings), bnStrings.r14.familyAlertTooEarly);
    });
  });

  group('Bangla first and text size', () {
    test('a new install starts in Bengali, whatever the phone', () async {
      SharedPreferences.setMockInitialValues({});
      final c = LocaleController();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.languageCode, 'bn');
    });

    test('a saved choice still wins', () async {
      SharedPreferences.setMockInitialValues({'pref_language_code': 'en'});
      final c = LocaleController();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.languageCode, 'en');
    });

    test('text size: Normal / Large / Larger, easy mode at least Large', () {
      expect(appTextFactor(AppTextSize.normal, easyMode: false), 1.0);
      expect(appTextFactor(AppTextSize.normal, easyMode: true), AppTextSize.large.factor);
      expect(appTextFactor(AppTextSize.larger, easyMode: true), AppTextSize.larger.factor);
      expect(AppTextSize.parse('junk'), AppTextSize.normal);
    });
  });

  group('phone-brand steps', () {
    test('each maker gets its own steps; unknown phones the general ones', () {
      expect(phoneFamily('Xiaomi'), 'xiaomi');
      expect(phoneFamily('POCO'), 'xiaomi');
      expect(phoneFamily('realme'), 'oppo');
      expect(phoneFamily('INFINIX MOBILITY LIMITED'), 'transsion');
      expect(phoneFamily('HONOR'), 'huawei');
      expect(phoneFamily('Google'), 'other');
      for (final s in [enRound14, bnRound14]) {
        for (final key in ['xiaomi', 'oppo', 'vivo', 'samsung', 'transsion', 'huawei', 'oneplus', 'other']) {
          expect(s.brandSteps[key], isNotEmpty, reason: key);
        }
      }
      expect(bnRound14.brandSteps['xiaomi']!.length, enRound14.brandSteps['xiaomi']!.length);
    });

    test('every Round 14 line exists in English and Bengali', () {
      expect(enStrings.r14, same(enRound14));
      expect(bnStrings.r14, same(bnRound14));
      expect(bnRound14.easyMode, isNot(enRound14.easyMode));
      expect(bnRound14.iGaveIt, 'আমি দিয়েছি');
    });
  });
}
