import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/features/medicine_box/data/medicine_box_repository.dart';
import 'package:mobile/features/medicine_box/domain/medicine_box_models.dart';
import 'package:mobile/notifications/push_service.dart';

/// The server's answer, stored as the phone's copy (no network in tests).
class _FakeApi implements MedicineBoxApi {
  MedicineBox box = const MedicineBox();

  @override
  Future<MedicineBox> get({String? forUserId}) async => box;

  @override
  Future<MedicineBox> save(Map<String, double> quantities, {String? forUserId}) async => box;

  @override
  Future<void> ignore(String routineId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MedicineBox _box(double remaining) => MedicineBox.fromJson({
      'startedAt': '2026-10-30T00:00:00.000Z',
      'items': [
        {
          'routineId': 'r1',
          'medicineName': 'Napa',
          'dosage': '500 mg',
          'doseAmount': '2 tablets',
          'unitsPerDose': 2,
          'quantity': 20,
          'countedAt': '2026-10-30T00:00:00.000Z',
          'remaining': remaining,
        },
      ],
    });

void main() {
  // Owner, 2026-10-31: a dose uses the number in its dose amount, else 1.
  test('units per dose', () {
    expect(unitsPerDoseOf('2 tablets'), 2);
    expect(unitsPerDoseOf('½ tablet'), 0.5);
    expect(unitsPerDoseOf('1/2'), 0.5);
    expect(unitsPerDoseOf('২টি'), 2);
    expect(unitsPerDoseOf('one'), 1);
    expect(unitsPerDoseOf(null), 1);
    expect(formatUnits(8), '8');
    expect(formatUnits(2.5), '2.5');
  });

  test('3 doses or fewer = low; less than one dose = ran out', () {
    expect(stockAlertFor(null), StockAlert.none);
    expect(stockAlertFor(4), StockAlert.none);
    expect(stockAlertFor(3), StockAlert.low);
    expect(stockAlertFor(1), StockAlert.low);
    expect(stockAlertFor(0), StockAlert.empty);
  });

  group('alerts from the phone copy', () {
    late AppDatabase db;
    late _FakeApi api;
    late MedicineBoxRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      api = _FakeApi();
      repo = MedicineBoxRepository(api: api, database: db);
    });
    tearDown(() => db.close());

    Future<void> takenHere(String id) => db.into(db.cachedMedicineDoses).insert(
          CachedMedicineDosesCompanion.insert(
            id: id,
            routineId: 'r1',
            medicineName: 'Napa',
            dosage: '1',
            scheduledAt: DateTime(2026, 10, 31, 8),
            doseStatus: 'TAKEN',
            takenAt: Value(DateTime(2026, 10, 31, 8, 5)),
            syncState: const Value('pending'),
            cachedAt: DateTime(2026, 10, 31),
          ),
        );

    test('counts doses taken here but not synced; each alert once per count', () async {
      api.box = _box(8); // 4 doses on the server
      await repo.refreshFromServer();
      expect((await repo.nextAlert('r1')).$1, StockAlert.none);

      await takenHere('d1'); // 3 doses left
      expect((await repo.nextAlert('r1')).$1, StockAlert.low);
      expect((await repo.nextAlert('r1')).$1, StockAlert.none); // shown once

      await takenHere('d2');
      await takenHere('d3');
      await takenHere('d4'); // none left
      expect((await repo.nextAlert('r1')).$1, StockAlert.empty);
      expect((await repo.nextAlert('r1')).$1, StockAlert.none);
    });

    test('a box not started (or a medicine not counted) never alerts', () async {
      api.box = const MedicineBox(items: []);
      await repo.refreshFromServer();
      expect((await repo.nextAlert('r1')).$1, StockAlert.none);
    });
  });

  test('"ran out" opens as a full screen; Refill opens its form; caregiver alerts route to the member', () {
    expect(
      alarmRouteForPayload('{"type":"MEDICINE_BOX","routineId":"r1","kind":"empty"}'),
      '/medicine-box/empty?routine=r1&alarm=1',
    );
    expect(alarmRouteForPayload('{"type":"MEDICINE_BOX","routineId":"r1","kind":"low"}'), isNull);
    expect(routeForNotificationData({'type': 'MEDICINE_BOX', 'routineId': 'r1', 'kind': 'refill'}), '/medicine-box/refill?routine=r1');
    expect(
      routeForNotificationData({'type': 'SYSTEM', 'kind': 'medicine_box_empty', 'memberUserId': 'm1'}),
      '/medicine-box?for=m1',
    );
    expect(
      routeForNotificationData({'type': 'PRESCRIPTION_UPDATE', 'memberUserId': 'm1', 'kind': 'member_prescription_ready'}),
      '/family/member/m1/prescriptions',
    );
  });
}
