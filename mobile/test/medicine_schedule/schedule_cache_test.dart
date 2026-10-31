import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/medicine_schedule/data/medicine_schedule_api.dart';
import 'package:mobile/features/medicine_schedule/data/medicine_schedule_repository.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'package:mobile/notifications/local_notifications_gateway.dart';
import 'package:mobile/notifications/notification_scheduler.dart';

class _QuietGateway implements LocalNotificationsGateway {
  @override
  Future<void> schedule(ScheduledReminder reminder, {required bool exact}) async {}

  @override
  Future<void> show(ScheduledReminder reminder) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<bool> canScheduleExact() async => true;
}

/// Serves whatever doses the test puts in [doses].
class _FakeApi extends MedicineScheduleApi {
  _FakeApi() : super(Dio());

  List<MedicineDoseModel> doses = [];

  @override
  Future<List<MedicineRoutineModel>> getActiveRoutines() async => const [];

  @override
  Future<List<MedicineDoseModel>> getToday() async => doses;

  @override
  Future<List<MedicineDoseModel>> getUpcoming({int days = 7}) async => const [];
}

MedicineDoseModel _dose(String id, {String status = 'PENDING'}) => MedicineDoseModel(
      id: id,
      routineId: 'r1',
      medicineName: 'Napa',
      dosage: '1 tablet',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      status: status,
    );

void main() {
  late AppDatabase db;
  late _FakeApi api;
  late MedicineScheduleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _FakeApi();
    repo = MedicineScheduleRepository(
      api: api,
      database: db,
      notificationScheduler: NotificationScheduler(
        gateway: _QuietGateway(),
        database: db,
        strings: () => enStrings,
        remindersEnabled: () => true,
      ),
    );
  });

  tearDown(() => db.close());

  Future<List<String>> cachedIds() async =>
      (await db.select(db.cachedMedicineDoses).get()).map((d) => d.id).toList()..sort();

  test('doses the server dropped (medicine edited or removed) leave the cache, so they stop reminding', () async {
    api.doses = [_dose('a'), _dose('b')];
    await repo.refreshFromServer();
    expect(await cachedIds(), ['a', 'b']);

    // The routine was changed: the server now has new doses instead.
    api.doses = [_dose('c')];
    await repo.refreshFromServer();
    expect(await cachedIds(), ['c']);
  });

  MedicineScheduleRepository repoAt(DateTime Function() clock) => MedicineScheduleRepository(
        api: api,
        database: db,
        notificationScheduler: NotificationScheduler(
          gateway: _QuietGateway(),
          database: db,
          strings: () => enStrings,
          remindersEnabled: () => true,
        ),
        clock: clock,
      );

  test('a dose marked taken offline survives a refresh until it syncs', () async {
    api.doses = [_dose('a')];
    await repo.refreshFromServer();
    // Its time has come (it was 2 hours ahead).
    final later = repoAt(() => DateTime.now().add(const Duration(hours: 2, minutes: 1)));
    expect(await later.markDoseTaken('a'), isTrue); // local only: syncState pending

    api.doses = [];
    await repo.refreshFromServer();
    final kept = await db.select(db.cachedMedicineDoses).get();
    expect(kept.single.id, 'a');
    expect(kept.single.doseStatus, 'TAKEN');
  });

  // Owner, 2026-10-31: from the dose's time until 1 hour before the next one.
  test('an upcoming dose can not be marked taken', () async {
    api.doses = [_dose('a')];
    await repo.refreshFromServer();
    expect(await repo.markDoseTaken('a'), isFalse);
    final row = (await db.select(db.cachedMedicineDoses).get()).single;
    expect(row.doseStatus, 'PENDING');
    expect(await db.select(db.outboxEntries).get(), isEmpty);
  });

  test("too late: 1 hour before the same medicine's next dose it closes", () async {
    final first = DateTime.now().add(const Duration(hours: 2));
    final next = first.add(const Duration(hours: 6));
    api.doses = [
      MedicineDoseModel(id: 'a', routineId: 'r1', medicineName: 'Napa', dosage: '1', scheduledAt: first, status: 'PENDING'),
      MedicineDoseModel(id: 'b', routineId: 'r1', medicineName: 'Napa', dosage: '1', scheduledAt: next, status: 'PENDING'),
    ];
    await repo.refreshFromServer();
    final tooLate = repoAt(() => next.subtract(const Duration(minutes: 59)));
    expect(await tooLate.markDoseTaken('a'), isFalse);
    final inTime = repoAt(() => next.subtract(const Duration(minutes: 61)));
    expect(await inTime.markDoseTaken('a'), isTrue);
  });

  test('takenWindowEnd: 08:00 with 14:00 next closes at 13:00; no next = a day later less 1 h', () {
    final eight = DateTime(2026, 10, 31, 8);
    MedicineDoseModel d(String id, DateTime at, [String routine = 'r1']) =>
        MedicineDoseModel(id: id, routineId: routine, medicineName: 'x', dosage: '1', scheduledAt: at, status: 'PENDING');
    final dose = d('a', eight);
    expect(
      takenWindowEnd(dose, [dose, d('b', DateTime(2026, 10, 31, 14)), d('c', DateTime(2026, 10, 31, 10), 'other')]),
      DateTime(2026, 10, 31, 13),
    );
    expect(takenWindowEnd(dose, [dose]), DateTime(2026, 11, 1, 7));
    final windowed = dose.withTakenUntil(DateTime(2026, 10, 31, 13));
    expect(windowed.canMarkTakenAt(DateTime(2026, 10, 31, 7, 30)), isFalse); // upcoming
    expect(windowed.canMarkTakenAt(DateTime(2026, 10, 31, 8)), isTrue);
    expect(windowed.canMarkTakenAt(DateTime(2026, 10, 31, 13)), isTrue);
    expect(windowed.canMarkTakenAt(DateTime(2026, 10, 31, 13, 1)), isFalse);
  });

  test('routine labels come through for "My medicines"', () {
    final r = ManagedRoutine.fromJson({
      'id': 'r1',
      'medicineName': 'Vitamin D',
      'dosage': '1000 IU',
      'frequency': '1 time a day',
      'startDate': '2026-10-29T00:00:00.000Z',
      'endDate': '2026-11-07T00:00:00.000Z',
      'selfAdded': true,
      'addedBy': 'CAREGIVER',
      'editedBy': 'YOU',
      'scheduleTimes': '["08:00","20:00"]',
    });
    expect(r.addedBy, ActedBy.caregiver);
    expect(r.editedBy, ActedBy.you);
    expect(r.scheduleTimes, ['08:00', '20:00']);
    expect(r.durationDays, 10);
    expect(r.continuous, isFalse);
  });
}
