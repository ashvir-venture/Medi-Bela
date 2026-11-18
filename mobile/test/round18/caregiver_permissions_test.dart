import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/domain/family_models.dart';
import 'package:mobile/features/family/presentation/caregiver_permissions.dart';
import 'package:mobile/providers/core_providers.dart';

class _FakeFamilyApi extends FamilyApi {
  _FakeFamilyApi(this.current) : super(Dio());

  CaregiverPermissions current;
  final saved = <(bool, bool)>[];

  @override
  Future<CaregiverPermissions> getPermissions() async => current;

  @override
  Future<CaregiverPermissions> setPermissions({required bool view, required bool manage}) async {
    saved.add((view, manage));
    return current = CaregiverPermissions(applies: true, view: view, manage: manage, answered: true, caregiverName: 'Rafi');
  }
}

Future<void> _pump(WidgetTester tester, _FakeFamilyApi api, String lang) async {
  SharedPreferences.setMockInitialValues({'pref_language_code': lang});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [familyApiProvider.overrideWithValue(api)]);
  addTearDown(container.dispose);
  await tester.runAsync(() async {
    container.read(stringsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  resetCaregiverPermissionPrompt();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: CaregiverPermissionPrompt())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final lang in ['en', 'bn']) {
    final s = (lang == 'bn' ? bnStrings : enStrings).r18;

    testWidgets('[$lang] a new member is asked; both start off; Manage turns View on', (tester) async {
      final api = _FakeFamilyApi(const CaregiverPermissions(applies: true, view: false, manage: false, answered: false, caregiverName: 'Rafi'));
      await _pump(tester, api, lang);
      expect(find.text(s.permTitle('Rafi')), findsOneWidget);
      final view = tester.widget<SwitchListTile>(find.byKey(const ValueKey('perm-view')));
      expect(view.value, isFalse);
      await tester.tap(find.byKey(const ValueKey('perm-manage')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('perm-view'))).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('perm-save')));
      await tester.pumpAndSettle();
      expect(api.saved, [(true, true)]);
      expect(find.text(s.permTitle('Rafi')), findsNothing);
    });

    testWidgets('[$lang] View off also turns Manage off', (tester) async {
      final api = _FakeFamilyApi(const CaregiverPermissions(applies: true, view: true, manage: true, answered: false, caregiverName: 'Rafi'));
      await _pump(tester, api, lang);
      await tester.tap(find.byKey(const ValueKey('perm-view')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('perm-manage'))).value, isFalse);
      await tester.tap(find.byKey(const ValueKey('perm-save')));
      await tester.pumpAndSettle();
      expect(api.saved, [(false, false)]);
    });
  }

  testWidgets('no question once answered', (tester) async {
    await _pump(tester, _FakeFamilyApi(const CaregiverPermissions(applies: true, view: true, manage: false, answered: true)), 'en');
    expect(find.byKey(const ValueKey('perm-save')), findsNothing);
  });

  testWidgets('no question for a caregiver', (tester) async {
    await _pump(tester, _FakeFamilyApi(const CaregiverPermissions(applies: false, view: false, manage: false, answered: true)), 'en');
    expect(find.byKey(const ValueKey('perm-save')), findsNothing);
  });

  test('the member page reads what the caregiver may do', () {
    final d = MemberStatusDetail.fromJson({
      'member': {'userId': 'm1', 'name': 'Abba', 'permissions': {'view': true, 'manage': false, 'answered': true}},
      'shared': true,
      'doses': [],
    });
    expect(d.permissions!.view, isTrue);
    expect(d.permissions!.manage, isFalse);
    expect(d.asCaregiver, isFalse, reason: 'no Manage: no "I gave it" and no easy-mode switch');
  });
}
