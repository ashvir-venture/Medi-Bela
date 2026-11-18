import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/lookups/lookups.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/medicine_box/domain/medicine_box_models.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'package:mobile/features/medicine_schedule/presentation/medicine_schedule_controller.dart';
import 'package:mobile/features/medicine_schedule/presentation/my_medicine_screen.dart';
import 'package:mobile/features/medicine_schedule/presentation/my_medicines_screen.dart';
import 'package:mobile/features/medicine_schedule/presentation/routine_form_screen.dart';
import 'package:mobile/features/reminders/domain/reminder_status.dart';
import 'package:mobile/features/reminders/presentation/reminder_status_controller.dart';
import 'package:mobile/providers/core_providers.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

MedicineDoseModel _dose(String id, String routine, String name, int hour, {String status = 'TAKEN'}) => MedicineDoseModel(
      id: id,
      routineId: routine,
      medicineName: name,
      dosage: '1 tablet',
      scheduledAt: _today.add(Duration(hours: hour)),
      status: status,
      takenAt: status == 'TAKEN' ? _today.add(Duration(hours: hour)) : null,
    );

ManagedRoutine _routine(String id, String name, {bool asNeeded = false, List<String> times = const ['08:00', '20:00']}) => ManagedRoutine(
      id: id,
      medicineName: name,
      dosage: '500 mg',
      frequency: '-',
      startDate: _today.subtract(const Duration(days: 40)),
      selfAdded: true,
      scheduleTimes: asNeeded ? const [] : times,
      asNeeded: asNeeded,
      pillColor: asNeeded ? null : 'b',
      takenToday: asNeeded ? [_today.add(const Duration(hours: 9))] : const [],
    );

Future<void> _pump(WidgetTester tester, Widget child, {String lang = 'en', List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues({'pref_language_code': lang});
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    reminderStatusProvider.overrideWith((ref) async => ReminderStatus.allOk),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  await tester.runAsync(() async {
    container.read(stringsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  final month = [
    for (var d = 1; d <= 30; d++) ...[
      MedicineDoseModel(
        id: 'm$d',
        routineId: 'r1',
        medicineName: 'Seclo',
        dosage: '',
        scheduledAt: _today.subtract(Duration(days: d)).add(const Duration(hours: 8)),
        status: d <= 4 ? 'MISSED' : 'TAKEN',
      ),
    ],
  ];

  for (final lang in ['en', 'bn']) {
    final s = (lang == 'bn' ? bnStrings : enStrings).r18;

    testWidgets('[$lang] My medicine: day arrows, doses by part of the day, when-needed card, one line per medicine', (tester) async {
      await _pump(
        tester,
        const MyMedicineScreen(),
        lang: lang,
        overrides: [
          refreshMedicineScheduleProvider.overrideWithValue(() async {}),
          lastWeekDosesProvider.overrideWith((ref) async => const []),
          dayDosesProvider.overrideWith((ref, day) => Stream.value(day == _today
              ? [_dose('d1', 'r1', 'Seclo', 8), _dose('d2', 'r1', 'Seclo', 20, status: 'PENDING')]
              : const <MedicineDoseModel>[])),
          managedRoutinesProvider.overrideWith((ref, forUserId) async => [_routine('r1', 'Seclo'), _routine('r2', 'Napa', asNeeded: true)]),
          last30DaysDosesProvider.overrideWith((ref) async => month),
        ],
      );
      expect(find.text(s.today), findsWidgets);
      expect(find.text(s.morning), findsOneWidget);
      expect(find.text(s.night), findsOneWidget);
      expect(find.text(s.dosesOfDay(1, 2)), findsOneWidget);
      expect(find.byKey(const ValueKey('as-needed-r2')), findsOneWidget);
      expect(find.text(s.tookOneNow), findsOneWidget);
      // Taken on 26 of the last 30 days (4 missed).
      expect(find.textContaining(s.takenDaysOf(26, 30)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('day-prev')));
      await tester.pumpAndSettle();
      expect(find.text(s.yesterday), findsOneWidget);
      expect(find.text(s.noDosesThisDay), findsOneWidget);
    });

    testWidgets('[$lang] Add medicine: When to take it switches the form', (tester) async {
      await _pump(
        tester,
        const RoutineFormScreen(args: RoutineFormArgs()),
        lang: lang,
        overrides: [
          lookupsProvider.overrideWith((ref) async => const Lookups(
                genders: [],
                divisions: [],
                districts: [],
                mealTimings: [LookupOption(id: 1, name: 'After meal')],
                medicineForms: [LookupOption(id: 1, name: 'Tablet'), LookupOption(id: 2, name: 'Syrup'), LookupOption(id: 3, name: 'Cream')],
              )),
        ],
      );
      // Form tiles: the common ones plus More for the rest.
      expect(find.byKey(const ValueKey('form-Tablet')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-Syrup')), findsOneWidget);
      expect(find.text(s.more), findsOneWidget);
      // Length chips.
      expect(find.byKey(const ValueKey('length-30')), findsOneWidget);
      expect(find.text(s.oneMonth), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('when-certainDays')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-6')), findsOneWidget); // Saturday chip

      await tester.tap(find.byKey(const ValueKey('when-asNeeded')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('times-2')), findsNothing);
      expect(find.text(s.mostPerDay), findsOneWidget);
      expect(find.text(s.summaryAsNeeded('', null)), findsOneWidget);
    });
  }

  test('box: a syrup in ml counts days from its ml a day', () {
    const item = MedicineBoxItem(routineId: 'r', medicineName: 'Tusca', dosage: '', unitsPerDose: 10, quantity: 200, remaining: 200, unit: 'ml', perDay: 20);
    expect(item.daysLeftWith(0), 10);
    expect(item.daysLeftWith(2), 9);
    expect(boxUnitsPerDoseOf('2 tsp', 'ml'), 10);
    expect(boxUnitsPerDoseOf('২ চামচ', 'ml'), 10);
    expect(boxUnitsPerDoseOf('1 tablet', 'tablet'), 1);
  });

  test('taken days ignore a day still running', () {
    final doses = [
      _dose('a', 'r', 'X', 1),
      MedicineDoseModel(id: 'b', routineId: 'r', medicineName: 'X', dosage: '', scheduledAt: _now.add(const Duration(hours: 2)), status: 'PENDING'),
    ];
    expect(takenDays('r', doses), (0, 0));
  });
}
