import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/core/utils/result.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/domain/user_model.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_repository.dart';
import 'package:mobile/features/family/domain/family_models.dart';
import 'package:mobile/features/profile/presentation/settings_screen.dart';
import 'package:mobile/features/reminders/domain/reminder_status.dart';
import 'package:mobile/features/reminders/presentation/reminder_status_controller.dart';
import 'package:mobile/providers/core_providers.dart';

const _user = UserModel(
  id: 'u1',
  phone: '+8801712345678',
  name: 'Rahima',
  address: null,
  role: 'USER',
  accountStatus: 'ACTIVE',
  languageCode: 'EN',
  notificationsEnabled: true,
  profileVisibleToFamily: true,
);

/// A signed-in session without a server.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(AppDatabase db)
      : super(api: AuthApi(Dio()), secureStorage: SecureStorageService(), database: db);

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<UserModel?> getCachedUser() async => _user;

  @override
  Future<Result<UserModel>> refreshProfileFromServer() async => const Result.success(_user);
}

class _FakeFamilyRepository extends FamilyRepository {
  _FakeFamilyRepository(AppDatabase db, this.members) : super(api: FamilyApi(Dio()), database: db);

  final List<FamilyMemberModel> members;

  @override
  Future<List<FamilyMemberModel>> getCachedMembers() async => members;

  @override
  Future<Result<List<FamilyMemberModel>>> refreshFromServer() async => Result.success(members);
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'pref_language_code': 'en'});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {required bool online, List<FamilyMemberModel> family = const []}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(db)),
        familyRepositoryProvider.overrideWithValue(_FakeFamilyRepository(db, family)),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(online)),
        reminderStatusProvider.overrideWith((ref) async => ReminderStatus.allOk),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  double y(WidgetTester tester, String text) => tester.getTopLeft(find.text(text).first).dy;

  testWidgets('five sections in order, Reminder check first in its section, actions last', (tester) async {
    await pump(tester, online: true);
    final s = enStrings;
    final order = [
      s.accountSection,
      s.editDetails,
      s.changePassword,
      s.remindersAndNotifications,
      s.reminderCheckTitle,
      s.pushNotificationsLabel,
      s.medicineRemindersLabel,
      s.noticesLabel,
      s.privacyAndFamily,
      s.hideFromFamily,
      s.appearanceAndLanguage,
      s.language,
      s.appearance,
      s.accountActions,
      s.deactivateAccount,
      s.deleteAccount,
    ];
    for (var i = 1; i < order.length; i++) {
      expect(y(tester, order[i]), greaterThan(y(tester, order[i - 1])), reason: '${order[i]} after ${order[i - 1]}');
    }
    expect(find.text(s.allGood), findsOneWidget);
    // Not in a family: no Leave family.
    expect(find.text(s.leaveFamily), findsNothing);
  });

  testWidgets('Leave family shows only for a family member', (tester) async {
    await pump(tester, online: true, family: [
      FamilyMemberModel(
        familyMemberId: 'm1',
        userId: 'u1',
        name: 'Rahima',
        phone: '+8801712345678',
        role: 'MEMBER',
        joinedAt: DateTime(2026, 10, 1),
      ),
    ]);
    expect(find.text(enStrings.leaveFamily), findsOneWidget);
  });

  testWidgets('offline: deactivate and delete are disabled', (tester) async {
    await pump(tester, online: false);
    final deactivate = tester.widget<ListTile>(find.ancestor(
      of: find.text(enStrings.deactivateAccount),
      matching: find.byType(ListTile),
    ));
    final delete = tester.widget<ListTile>(find.ancestor(
      of: find.text(enStrings.deleteAccount),
      matching: find.byType(ListTile),
    ));
    expect(deactivate.enabled, isFalse);
    expect(delete.enabled, isFalse);
  });
}
