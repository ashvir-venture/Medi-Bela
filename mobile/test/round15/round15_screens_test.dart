import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/care/domain/care_content.dart';
import 'package:mobile/features/care/domain/care_models.dart';
import 'package:mobile/features/care/presentation/care_providers.dart';
import 'package:mobile/features/care/presentation/condition_screen.dart';
import 'package:mobile/features/care/presentation/crisis_sheet.dart';
import 'package:mobile/features/care/presentation/limits_screen.dart';
import 'package:mobile/features/care/presentation/my_care_screen.dart';
import 'package:mobile/features/care/presentation/records_screens.dart';
import 'package:mobile/features/health/domain/health_models.dart';
import 'package:mobile/features/health/presentation/health_controller.dart';
import 'package:mobile/providers/core_providers.dart';

const _lookups = CareLookups(conditions: [
  ConditionInfo(code: 'diabetes', nameEn: 'Diabetes', nameBn: 'ডায়াবেটিস'),
  ConditionInfo(code: 'bp', nameEn: 'High blood pressure', nameBn: 'উচ্চ রক্তচাপ'),
]);

Future<void> pump(WidgetTester tester, Widget child, {String lang = 'en', CareOverview care = CareOverview.empty, RecordsOverview records = RecordsOverview.empty}) async {
  SharedPreferences.setMockInitialValues({'pref_language_code': lang});
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    careOverviewProvider.overrideWith((ref) => Stream.value(care)),
    recordsOverviewProvider.overrideWith((ref) => Stream.value(records)),
    careLookupsProvider.overrideWith((ref) async => _lookups),
    healthRecordsProvider.overrideWith((ref) => Stream.value(const <HealthRecordModel>[])),
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
  for (final lang in ['en', 'bn']) {
    final s = lang == 'bn' ? bnStrings.r15 : enStrings.r15;
    final bn = lang == 'bn';

    testWidgets('[$lang] My care step lists the conditions with Later and Get started', (tester) async {
      await pump(tester, const MyCareScreen(signupStep: true), lang: lang);
      expect(find.text(s.whatCare), findsOneWidget);
      expect(find.text(bn ? 'ডায়াবেটিস' : 'Diabetes'), findsOneWidget);
      expect(find.text(tr(conditionFallbackNames['pregnancy']!, bn)), findsOneWidget);
      expect(find.text(s.later), findsOneWidget);
      expect(find.text(s.getStarted), findsOneWidget);
    });

    testWidgets('[$lang] the BP crisis sheet: measure again, 999, 16263 and Alert family', (tester) async {
      await pump(tester, const Scaffold(body: CrisisSheet(kind: CrisisKind.bp, reading: '185/110 mmHg', level: '180/120')), lang: lang);
      expect(find.text(tr(bpCrisisTitle, bn)), findsOneWidget);
      expect(find.text(s.call999), findsOneWidget);
      expect(find.text(s.call16263), findsOneWidget);
      expect(find.text(s.alertFamily), findsOneWidget);
      expect(find.textContaining(s.n('180/120')), findsOneWidget);
    });

    testWidgets('[$lang] the low-sugar sheet for a caregiver has no Alert family', (tester) async {
      await pump(tester, const Scaffold(body: CrisisSheet(kind: CrisisKind.sugar, reading: '2.6 mmol/L', forMember: true)), lang: lang);
      expect(find.text(tr(sugarCrisisTitle, bn)), findsOneWidget);
      expect(find.text(s.alertFamily), findsNothing);
    });

    testWidgets('[$lang] the BP page: danger card, habits, symptoms and questions', (tester) async {
      await pump(tester, const ConditionScreen(code: 'bp'), lang: lang, care: const CareOverview(conditions: ['bp']));
      expect(find.text(tr(conditionContent['bp']!.danger!.title, bn)), findsOneWidget);
      expect(find.text(s.todaysHabits), findsOneWidget);
      expect(find.text(tr(conditionContent['bp']!.habits.first.text, bn)), findsOneWidget);
      await tester.scrollUntilVisible(find.text(s.questions), 400);
      expect(find.text(s.howFeel), findsOneWidget);
      expect(find.text(s.questions), findsOneWidget);
    });

    testWidgets('[$lang] picking an urgent symptom shows "call 999"', (tester) async {
      await pump(tester, const ConditionScreen(code: 'bp'), lang: lang, care: const CareOverview(conditions: ['bp']));
      final chest = tr(conditionContent['bp']!.symptoms.firstWhere((x) => x.key == 'chest').text, bn);
      await tester.scrollUntilVisible(find.text(chest), 300);
      await tester.tap(find.text(chest));
      await tester.pumpAndSettle();
      expect(find.text(tr(urgentSignNote, bn)), findsOneWidget);
    });

    testWidgets('[$lang] limits: empty means no alert, the tell-family switch', (tester) async {
      await pump(tester, const LimitsScreen(), lang: lang, care: const CareOverview(conditions: ['diabetes']));
      expect(find.text(s.limitsIntro), findsOneWidget);
      expect(find.text(s.limFastLo), findsOneWidget);
      await tester.scrollUntilVisible(find.text(s.tellFamily), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text(s.tellFamily), findsOneWidget);
    });

    testWidgets('[$lang] health records: the PDF card and the sections', (tester) async {
      await pump(tester, const RecordsScreen(), lang: lang);
      expect(find.text(s.pdfCardTitle), findsOneWidget);
      expect(find.text(s.upcomingTests), findsOneWidget);
      expect(find.text(s.testReports), findsOneWidget);
      await tester.scrollUntilVisible(find.text(s.prescriptions), 300);
      expect(find.text(s.recordsNote), findsOneWidget);
    });
  }
}
