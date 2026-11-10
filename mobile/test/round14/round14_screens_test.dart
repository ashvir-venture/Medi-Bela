import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/home/presentation/easy_home_screen.dart';
import 'package:mobile/features/home/presentation/home_top.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'package:mobile/features/medicine_schedule/presentation/medicine_schedule_controller.dart';
import 'package:mobile/features/reminders/presentation/notification_look_screen.dart';
import 'package:mobile/features/reminders/presentation/reminder_rules_screen.dart';
import 'package:mobile/notifications/reminder_timing.dart';
import 'package:mobile/providers/core_providers.dart';
import 'package:mobile/widgets/main_scaffold.dart';

MedicineDoseModel dose(String id, DateTime at, {String status = 'PENDING'}) => MedicineDoseModel(
      id: id,
      routineId: 'r-$id',
      medicineName: 'Napa $id',
      dosage: '1 tablet',
      scheduledAt: at,
      status: status,
    );

Future<void> pump(WidgetTester tester, Widget child, {String lang = 'en', List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues({'pref_language_code': lang});
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  await tester.runAsync(() async {
    container.read(stringsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => ReminderTiming.current = const ReminderTiming());

  testWidgets('quick add lists the five things to add, in Bengali first', (tester) async {
    await pump(tester, const Scaffold(body: QuickAddSheet()), lang: 'bn');
    final s = bnStrings.r14;
    for (final label in [s.whatToAdd, s.qAddMedicine, s.qPrescription, s.qReading, s.qReminder, s.qBox]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets("Home's card: a due time shows a green Taken and a red Later", (tester) async {
    final now = DateTime.now();
    final at = now.subtract(const Duration(minutes: 3));
    await pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: Padding(padding: EdgeInsets.only(top: 80), child: TodayHeroCard()))),
      overrides: [
        todaysMedicineProvider.overrideWith((ref) => Stream.value([dose('a', at)])),
      ],
    );
    final taken = tester.widget<FilledButton>(find.ancestor(of: find.text(enStrings.takenAction), matching: find.byType(FilledButton)));
    final later = tester.widget<FilledButton>(find.ancestor(of: find.text(enStrings.reminderLaterAction), matching: find.byType(FilledButton)));
    expect(taken.style!.backgroundColor!.resolve({}), AppPalette.light.taken);
    expect(later.style!.backgroundColor!.resolve({}), AppPalette.light.later);
    expect(find.text('Napa a'), findsOneWidget);
    expect(find.text(enStrings.r14.doneOf(0, 1)), findsOneWidget);
  });

  testWidgets("Home's card: nothing added yet offers Prescription and Add medicine", (tester) async {
    await pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: Padding(padding: EdgeInsets.only(top: 80), child: TodayHeroCard()))),
      overrides: [todaysMedicineProvider.overrideWith((ref) => Stream.value(const <MedicineDoseModel>[]))],
    );
    expect(find.text(enStrings.r14.noMedicinesAdded), findsOneWidget);
    expect(find.text(enStrings.r14.prescriptionShort), findsOneWidget);
    expect(find.text(enStrings.r14.addMedicineShort), findsOneWidget);
  });

  testWidgets('easy home: one big Taken when due; the preview can not be tapped', (tester) async {
    final at = DateTime.now().subtract(const Duration(minutes: 2));
    var taken = <String>[];
    await pump(
      tester,
      Scaffold(
        body: EasyHomeBody(
          name: 'Rahim',
          doses: [dose('a', at)],
          onTake: (open) async => taken = open.map((d) => d.id).toList(),
        ),
      ),
    );
    expect(find.text(enStrings.r14.easyEmergency), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('easy-taken')));
    await tester.pump();
    expect(taken, ['a']);

    await pump(tester, Scaffold(body: EasyHomeBody(name: 'Rahim', doses: [dose('a', at)])));
    final button = tester.widget<FilledButton>(find.ancestor(of: find.text(enStrings.r14.easyTakeAll), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
    expect(find.text(enStrings.r14.easyIsOn), findsNothing);
  });

  testWidgets('Routine and reminders: defaults shown; a family alert before the last ring is refused', (tester) async {
    await pump(
      tester,
      const ReminderRulesScreen(),
      overrides: [
        reminderRulesProvider.overrideWith((ref) async => const ReminderRulesState(
              defaults: ReminderTiming(),
              own: ReminderRules(),
            )),
      ],
    );
    final s = enStrings.r14;
    expect(find.text(s.defaultTag), findsNWidgets(4));
    expect(find.text(s.lastRing(47)), findsOneWidget);
    expect(find.byKey(const ValueKey('rules-too-early')), findsNothing);

    // Family alert down from 50 to 40: before the last ring ends at 47.
    final alertRow = find.ancestor(of: find.text(s.familyAlertAfter), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: alertRow, matching: find.byIcon(Icons.remove)));
    await tester.pumpAndSettle();
    expect(find.text(s.minutes(40)), findsOneWidget);
    expect(find.byKey(const ValueKey('rules-too-early')), findsOneWidget);
    final save = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(save.onPressed, isNull);

    // Fewer rings: the last one ends at 32, so 40 is fine again.
    final ringsRow = find.ancestor(of: find.text(s.ringsCount), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: ringsRow, matching: find.byIcon(Icons.remove)));
    await tester.pumpAndSettle();
    expect(find.text(s.lastRing(32)), findsOneWidget);
    expect(find.byKey(const ValueKey('rules-too-early')), findsNothing);
  });

  testWidgets('what notifications look like: full page vs normal, no medicine names', (tester) async {
    await pump(tester, const NotificationLookScreen(), lang: 'bn');
    final s = bnStrings.r14;
    expect(find.text(s.npFullPage), findsNWidgets(3));
    expect(find.text(s.npNormal), findsNWidgets(2));
    expect(find.text(s.npMedicineSample), findsOneWidget);
  });

  test('Profile is no tab; the + and the AI button live in the scaffold', () {
    expect(tabIndexForLocation(Uri.parse('/profile')), 0);
    expect(isTabRoot(Uri.parse('/profile')), isFalse);
    expect(isTabRoot(Uri.parse('/health')), isTrue);
  });
}
