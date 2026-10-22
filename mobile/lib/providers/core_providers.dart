import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/network/connectivity_service.dart';
import '../core/network/dio_client.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/session_notifier.dart';
import '../features/family/data/family_api.dart';
import '../features/family/data/family_repository.dart';
import '../features/health/data/health_api.dart';
import '../features/health/data/health_record_repository.dart';
import '../features/health/data/health_record_sync_handler.dart';
import '../features/health/data/health_reminder_repository.dart';
import '../features/health/data/health_reminder_sync_handler.dart';
import '../features/medicine_schedule/data/dose_sync_handler.dart';
import '../features/medicine_schedule/data/medicine_schedule_api.dart';
import '../features/medicine_schedule/data/medicine_schedule_repository.dart';
import '../features/notices/data/notices_api.dart';
import '../features/prescription/data/prescription_api.dart';
import '../features/prescription/data/prescription_local_repository.dart';
import '../features/prescription/data/prescription_sync_handler.dart';
import '../main.dart' show flutterLocalNotificationsPlugin;
import '../notifications/local_notifications_gateway.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/push_service.dart';
import '../router/app_router.dart';
import '../sync/sync_handler.dart';
import '../sync/sync_service.dart';

/// One Drift database for the app's lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// `true`/`false` once known; starts by resolving the current status so
/// the very first frame already knows whether we're online.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOnline;
  yield* service.onStatusChange;
});

final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return DioClient(
    secureStorage: secureStorage,
    onSessionExpired: () async {
      ref.read(sessionNotifierProvider.notifier).setLoggedIn(false);
    },
  );
});

// ---- Auth ----

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioClientProvider).dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiProvider),
    secureStorage: ref.watch(secureStorageProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

// ---- Family ----

final familyApiProvider = Provider<FamilyApi>((ref) {
  return FamilyApi(ref.watch(dioClientProvider).dio);
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(
    api: ref.watch(familyApiProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

// ---- Prescription (local-first drafts + outbox) ----

final prescriptionApiProvider = Provider<PrescriptionApi>((ref) {
  return PrescriptionApi(ref.watch(dioClientProvider).dio);
});

final prescriptionLocalRepositoryProvider =
    Provider<PrescriptionLocalRepository>((ref) {
  return PrescriptionLocalRepository(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(prescriptionApiProvider),
  );
});

// ---- Notifications ----

final localNotificationsGatewayProvider = Provider<LocalNotificationsGateway>((ref) {
  return FlutterLocalNotificationsGateway(flutterLocalNotificationsPlugin);
});

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(
    gateway: ref.watch(localNotificationsGatewayProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    dio: ref.watch(dioClientProvider).dio,
    secureStorage: ref.watch(secureStorageProvider),
    localPlugin: flutterLocalNotificationsPlugin,
    navigate: (route) => ref.read(appRouterProvider).go(route),
  );
});

// ---- Medicine schedule (dose tracking, synchronized) ----

final medicineScheduleApiProvider = Provider<MedicineScheduleApi>((ref) {
  return MedicineScheduleApi(ref.watch(dioClientProvider).dio);
});

final medicineScheduleRepositoryProvider =
    Provider<MedicineScheduleRepository>((ref) {
  return MedicineScheduleRepository(
    api: ref.watch(medicineScheduleApiProvider),
    database: ref.watch(appDatabaseProvider),
    notificationScheduler: ref.watch(notificationSchedulerProvider),
  );
});

// ---- Health (reminders + records) ----

final healthApiProvider = Provider<HealthApi>((ref) {
  return HealthApi(ref.watch(dioClientProvider).dio);
});

final healthReminderRepositoryProvider = Provider<HealthReminderRepository>((ref) {
  return HealthReminderRepository(
    api: ref.watch(healthApiProvider),
    database: ref.watch(appDatabaseProvider),
    notificationScheduler: ref.watch(notificationSchedulerProvider),
  );
});

final healthRecordRepositoryProvider = Provider<HealthRecordRepository>((ref) {
  return HealthRecordRepository(
    api: ref.watch(healthApiProvider),
    database: ref.watch(appDatabaseProvider),
  );
});

// ---- Notices (read-only, no offline caching — see myNoticesProvider) ----

final noticesApiProvider = Provider<NoticesApi>((ref) {
  return NoticesApi(ref.watch(dioClientProvider).dio);
});

// ---- Sync engine ----

final syncHandlersProvider = Provider<List<SyncHandler>>((ref) {
  return [
    PrescriptionSyncHandler(
      api: ref.watch(prescriptionApiProvider),
      database: ref.watch(appDatabaseProvider),
    ),
    DoseSyncHandler(
      api: ref.watch(medicineScheduleApiProvider),
      database: ref.watch(appDatabaseProvider),
    ),
    HealthReminderSyncHandler(
      api: ref.watch(healthApiProvider),
      database: ref.watch(appDatabaseProvider),
    ),
    HealthRecordSyncHandler(
      api: ref.watch(healthApiProvider),
      database: ref.watch(appDatabaseProvider),
    ),
  ];
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    database: ref.watch(appDatabaseProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    handlers: ref.watch(syncHandlersProvider),
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
