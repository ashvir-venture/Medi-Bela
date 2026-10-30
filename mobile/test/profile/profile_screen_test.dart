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
import 'package:mobile/features/profile/presentation/profile_screen.dart';
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
  _FakeFamilyRepository(AppDatabase db) : super(api: FamilyApi(Dio()), database: db);

  @override
  Future<List<FamilyMemberModel>> getCachedMembers() async => const [];

  @override
  Future<Result<List<FamilyMemberModel>>> refreshFromServer() async => const Result.success([]);
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'pref_language_code': 'en'});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  testWidgets('Edit details and Change password sit right under the profile card, then Settings, then Log out',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(db)),
        familyRepositoryProvider.overrideWithValue(_FakeFamilyRepository(db)),
        connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ));
    // Fixed frames, not pumpAndSettle: the profile keeps a live sync-count
    // stream open, so the tree never "settles".
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    double y(String text) => tester.getTopLeft(find.text(text).first).dy;
    final s = enStrings;
    final order = ['Rahima', s.editDetails, s.changePassword, s.settings, s.logout];
    for (var i = 1; i < order.length; i++) {
      expect(y(order[i]), greaterThan(y(order[i - 1])), reason: '${order[i]} after ${order[i - 1]}');
    }

    // Unmount and let Drift's stream timers finish before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
