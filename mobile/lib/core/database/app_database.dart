import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Cached copy of the current user's profile (from `GET /users/me`).
///
/// The UI always reads from this table first (see [AuthRepository]) so
/// the profile screen renders instantly on app open, even offline. It is
/// refreshed from the network opportunistically, never the other way
/// around — the server is authoritative for this data.
///
/// `@DataClassName` pins the generated row class name explicitly rather
/// than relying on drift's automatic singularization guesswork (e.g.
/// "Entries" -> "Entry"), since that codegen can't be run/verified in
/// this environment.
@DataClassName('CachedUser')
class CachedUsers extends Table {
  TextColumn get id => text()();
  TextColumn get phone => text()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get role => text()();
  TextColumn get languageCode => text().withDefault(const Constant('EN'))();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get profileVisibleToFamily =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached family + member list (from `GET /family` and `/family/members`).
/// Read-only cache — family membership changes always go through the API
/// directly (there's no offline "create family" use case worth queuing).
@DataClassName('CachedFamilyMember')
class CachedFamilyMembers extends Table {
  TextColumn get familyMemberId => text()();
  TextColumn get familyId => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get role => text()(); // OWNER | MEMBER
  TextColumn get address => text().nullable()();
  DateTimeColumn get joinedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {familyMemberId};
}

/// Generic offline action queue ("outbox" pattern).
///
/// Any user action performed offline that needs to reach the server is
/// written here first, then drained by [SyncService] once connectivity
/// returns. [id] is a client-generated UUID and doubles as an idempotency
/// key, so a retried sync can't create the same record twice server-side.
@DataClassName('OutboxEntry')
class OutboxEntries extends Table {
  TextColumn get id => text()(); // uuid, also the idempotency key
  TextColumn get entityType => text()(); // e.g. 'prescriptionDraft'
  TextColumn get entityLocalId => text()();
  TextColumn get operation => text()(); // create | update | delete
  TextColumn get payloadJson => text()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending|syncing|failed|synced
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-authored prescription entries ("Direct entry" quick action on
/// Home). Saved locally first; queued into [OutboxEntries] for upload once
/// the backend's prescription endpoint exists. Users can only create
/// entries for themselves here — the equivalent pharmacist flow (entry on
/// behalf of any patient) is a separate, not-yet-built screen that will
/// call the same backend endpoint with a different target user.
@DataClassName('PrescriptionDraft')
class PrescriptionDrafts extends Table {
  TextColumn get id => text()(); // uuid, becomes the server id on first sync
  TextColumn get imageLocalPath => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('draft'))(); // draft|queued|syncing|synced|failed
  TextColumn get serverId => text().nullable()();
  // The prescription's review status once known from the server
  // (PENDING/COMPLETED/REJECTED). Distinct from [status] above, which
  // tracks the *upload/sync* state, not the pharmacist's review state.
  // Null until the draft has synced at least once.
  TextColumn get serverStatus => text().nullable()();
  TextColumn get rejectionReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached copy of a completed medicine routine (from
/// `GET /medicine-schedule/routines`). Read-only cache — routines are
/// only ever created server-side, by admin/pharmacist prescription
/// completion, so there's nothing for the client to queue/write here.
@DataClassName('CachedMedicineRoutine')
class CachedMedicineRoutines extends Table {
  TextColumn get id => text()();
  TextColumn get medicineName => text()();
  TextColumn get dosage => text()();
  TextColumn get frequency => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached individual scheduled doses (from `GET /medicine-schedule/today`
/// and `.../upcoming`), so "today's medicine" renders instantly offline
/// from the last successful sync. Also the source of truth for local
/// notification scheduling — see `NotificationScheduler`.
@DataClassName('CachedMedicineDose')
class CachedMedicineDoses extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text()();
  TextColumn get medicineName => text()();
  TextColumn get dosage => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  // PENDING|TAKEN|MISSED|SKIPPED — mirrors the backend's DoseStatus.
  // Updated optimistically the instant the user taps "Taken", before the
  // server has confirmed anything (see [syncState] below).
  TextColumn get doseStatus => text()();
  DateTimeColumn get takenAt => dateTime().nullable()();
  // synced|pending|syncing|failed — sync state of *this dose's* most
  // recent local action (marking taken), distinct from [doseStatus]
  // itself. A dose can show TAKEN with syncState=pending: the UI already
  // reflects the user's action, the outbox just hasn't confirmed it yet.
  TextColumn get syncState => text().withDefault(const Constant('synced'))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks which local notification is currently scheduled for which
/// dose, so reconciliation (see `NotificationScheduler.reconcile`) can
/// diff "what's scheduled" against "what should be scheduled" and only
/// touch what actually changed — never blindly cancel-and-reschedule
/// everything on every sync (that would flicker/duplicate on Android in
/// practice, and wastes battery).
@DataClassName('ScheduledMedicineNotification')
class ScheduledMedicineNotifications extends Table {
  TextColumn get doseId => text()(); // FK-ish to CachedMedicineDoses.id
  IntColumn get notificationId => integer()(); // deterministic hash of doseId
  DateTimeColumn get scheduledAt => dateTime()();

  @override
  Set<Column> get primaryKey => {doseId};
}

/// Cached health reminders (from `GET /health-reminders`). Mirrors
/// [PrescriptionDrafts]' status-tracking approach: reminders are always
/// server-created (via suggestion rules), but *completing* one is a
/// local-first, offline-capable action, so this row needs its own
/// [syncState] the same way a dose does.
@DataClassName('CachedHealthReminder')
class CachedHealthReminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get status => text()(); // PENDING|COMPLETED|DISMISSED
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('synced'))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-authored basic health records (blood pressure, blood sugar,
/// weight, etc). Follows the same offline-create pattern as
/// [PrescriptionDrafts]: written locally first with a client-generated
/// id, queued for upload, and [serverId] filled in once confirmed.
@DataClassName('HealthRecordDraft')
class HealthRecordDrafts extends Table {
  TextColumn get id => text()(); // client-generated uuid
  TextColumn get type => text()(); // BLOOD_PRESSURE|BLOOD_SUGAR|WEIGHT|TEMPERATURE|HEART_RATE|OTHER
  TextColumn get value => text()();
  TextColumn get unit => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('draft'))(); // draft|queued|syncing|synced|failed
  TextColumn get serverId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    CachedUsers,
    CachedFamilyMembers,
    OutboxEntries,
    PrescriptionDrafts,
    CachedMedicineRoutines,
    CachedMedicineDoses,
    ScheduledMedicineNotifications,
    CachedHealthReminders,
    HealthRecordDrafts,
  ],
)
class AppDatabase extends _$AppDatabase {
  // Shared across isolates: Done / Later on a reminder and the reminder
  // backstop push can run in a background isolate while the app is open.
  AppDatabase()
      : super(driftDatabase(
          name: 'carebridge',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ));

  /// Used by tests to inject an in-memory executor.
  AppDatabase.forTesting(super.executor);

  /// Removes EVERY per-user row. Called on logout so the next person to use
  /// this device can never see (or have their outbox act on) the previous
  /// user's family, medicine, health or prescription data. Add new tables here.
  Future<void> clearAllUserData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(prescriptionDrafts, prescriptionDrafts.serverStatus);
            await m.addColumn(prescriptionDrafts, prescriptionDrafts.rejectionReason);
            await m.createTable(cachedMedicineRoutines);
            await m.createTable(cachedMedicineDoses);
          }
          if (from < 3) {
            await m.addColumn(cachedMedicineDoses, cachedMedicineDoses.takenAt);
            await m.addColumn(cachedMedicineDoses, cachedMedicineDoses.syncState);
            await m.createTable(scheduledMedicineNotifications);
            await m.createTable(cachedHealthReminders);
            await m.createTable(healthRecordDrafts);
          }
        },
      );
}
