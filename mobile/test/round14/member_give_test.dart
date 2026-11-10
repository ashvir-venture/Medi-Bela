import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/result.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/domain/user_model.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_repository.dart';
import 'package:mobile/features/family/domain/family_models.dart';
import 'package:mobile/features/family/presentation/member_status_screen.dart';
import 'package:mobile/providers/core_providers.dart';

const _me = UserModel(
  id: 'carer',
  phone: '01712345678',
  name: 'Rafi',
  address: null,
  role: 'USER',
  accountStatus: 'ACTIVE',
  languageCode: 'EN',
  notificationsEnabled: true,
  profileVisibleToFamily: true,
);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(AppDatabase db) : super(api: AuthApi(Dio()), secureStorage: SecureStorageService(), database: db);

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<UserModel?> getCachedUser() async => _me;

  @override
  Future<Result<UserModel>> refreshProfileFromServer() async => const Result.success(_me);
}

/// Rafi is the caregiver; his father has a dose due now and one taken late.
class _FakeFamilyRepository extends FamilyRepository {
  _FakeFamilyRepository(AppDatabase db, {required this.asCaregiver}) : super(api: FamilyApi(Dio()), database: db);

  final bool asCaregiver;
  final given = <String>[];
  final easy = <bool>[];

  List<FamilyMemberModel> get _members => [
        FamilyMemberModel(familyMemberId: 'm1', userId: 'carer', name: 'Rafi', phone: '1', role: 'CAREGIVER', joinedAt: DateTime(2026)),
        FamilyMemberModel(familyMemberId: 'm2', userId: 'abba', name: 'Rahim', phone: '2', role: 'MEMBER', joinedAt: DateTime(2026)),
      ];

  @override
  Future<List<FamilyMemberModel>> getCachedMembers() async => _members;

  @override
  Future<Result<List<FamilyMemberModel>>> refreshFromServer() async => Result.success(_members);

  @override
  Future<Result<MemberStatusDetail>> getMemberStatus(String userId) async => Result.success(MemberStatusDetail(
        userId: 'abba',
        name: 'Rahim',
        shared: true,
        easyMode: asCaregiver ? easy.lastOrNull ?? false : null,
        doses: [
          MemberDoseStatus(
            id: asCaregiver ? 'd1' : null,
            medicineName: 'Metformin',
            scheduledAt: DateTime.now().subtract(const Duration(minutes: 5)),
            status: given.contains('d1') ? 'TAKEN' : 'PENDING',
            takenLate: given.contains('d1') ? false : null,
            givenByCaregiver: given.contains('d1'),
          ),
          MemberDoseStatus(
            medicineName: 'Losartan',
            scheduledAt: DateTime.now().subtract(const Duration(hours: 3)),
            status: 'TAKEN',
            takenLate: true,
          ),
        ],
      ));

  @override
  Future<Result<void>> giveDose(String memberUserId, String doseId) async {
    given.add(doseId);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setEasyMode(String memberUserId, bool on) async {
    easy.add(on);
    return const Result.success(null);
  }
}

void main() {
  late AppDatabase db;
  setUp(() {
    SharedPreferences.setMockInitialValues({'pref_language_code': 'en'});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<_FakeFamilyRepository> pump(WidgetTester tester, {required bool asCaregiver}) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final family = _FakeFamilyRepository(db, asCaregiver: asCaregiver);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(db)),
      familyRepositoryProvider.overrideWithValue(family),
      connectivityStreamProvider.overrideWith((ref) => Stream.value(true)),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.read(stringsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(), home: const MemberStatusScreen(userId: 'abba')),
    ));
    await tester.pumpAndSettle();
    return family;
  }

  testWidgets('the caregiver gives a due dose ("I gave it") and sees it as given', (tester) async {
    final family = await pump(tester, asCaregiver: true);
    final s = enStrings.r14;
    // Late is shown for the dose taken after the family-alert time.
    expect(find.text(s.outcomeLate), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('give-d1')));
    await tester.pumpAndSettle();
    expect(family.given, ['d1']);
    expect(find.text(s.givenByCaregiver), findsOneWidget);
    expect(find.byKey(const ValueKey('give-d1')), findsNothing);

    // Easy mode for him.
    await tester.tap(find.byKey(const ValueKey('member-easy-mode')));
    await tester.pumpAndSettle();
    expect(family.easy, [true]);
  });

  testWidgets('without the caregiver view (no dose ids): no "I gave it", no easy-mode switch', (tester) async {
    await pump(tester, asCaregiver: false);
    expect(find.text(enStrings.r14.iGaveIt), findsNothing);
    expect(find.byKey(const ValueKey('member-easy-mode')), findsNothing);
  });
}
