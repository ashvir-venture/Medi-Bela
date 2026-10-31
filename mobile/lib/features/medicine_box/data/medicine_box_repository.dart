import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/database/app_database.dart';
import '../domain/medicine_box_models.dart';

const _boxKey = 'medicine_box';
const _alertsKey = 'medicine_box_alerts';

class MedicineBoxApi {
  MedicineBoxApi(this._dio);

  final Dio _dio;

  Map<String, dynamic> _for(String? forUserId) => {if (forUserId != null) 'forUserId': forUserId};

  Future<MedicineBox> get({String? forUserId}) async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.medicineBox, queryParameters: _for(forUserId));
    return MedicineBox.fromJson(response.data!);
  }

  /// Start / Refill: the totals now ({routineId: quantity}).
  Future<MedicineBox> save(Map<String, double> quantities, {String? forUserId}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.medicineBox,
      data: {
        'items': [
          for (final e in quantities.entries) {'routineId': e.key, 'quantity': e.value},
        ],
      },
      queryParameters: _for(forUserId),
    );
    return MedicineBox.fromJson(response.data!);
  }

  Future<void> ignore(String routineId) => _dio.post<void>(ApiEndpoints.medicineBoxIgnore(routineId));
}

/// My medicine box on the phone: the last server answer (so counts and
/// alerts work offline), minus doses marked taken here and not yet synced.
class MedicineBoxRepository {
  MedicineBoxRepository({required MedicineBoxApi api, required AppDatabase database})
      : _api = api,
        _db = database;

  final MedicineBoxApi _api;
  final AppDatabase _db;

  Future<MedicineBox?> cached() async {
    final json = await _read(_boxKey);
    return json == null ? null : MedicineBox.fromJson(json);
  }

  Stream<MedicineBox?> watch() => (_db.select(_db.cachedDocuments)..where((t) => t.key.equals(_boxKey)))
      .watchSingleOrNull()
      .map((row) => row == null ? null : MedicineBox.fromJson(jsonDecode(row.json) as Map<String, dynamic>));

  Future<MedicineBox> refreshFromServer() async {
    final box = await _api.get();
    await _store(box);
    return box;
  }

  Future<MedicineBox> save(Map<String, double> quantities) async {
    final box = await _api.save(quantities);
    await _store(box);
    // A new count starts its alerts over.
    final shown = await _shownAlerts();
    shown.removeWhere((k, _) => quantities.containsKey(k));
    await _write(_alertsKey, shown);
    return box;
  }

  Future<void> ignore(String routineId) => _api.ignore(routineId);

  /// Doses of [routineId] marked taken on this phone the server hasn't seen.
  Future<int> pendingTaken(String routineId, DateTime? since) async {
    final rows = await (_db.select(_db.cachedMedicineDoses)
          ..where((t) =>
              t.routineId.equals(routineId) &
              t.doseStatus.equals('TAKEN') &
              t.syncState.isIn(const ['pending', 'syncing', 'failed'])))
        .get();
    return rows.where((r) => since == null || r.takenAt == null || !r.takenAt!.isBefore(since)).length;
  }

  /// Which alert should show for [routineId] now, at most once per count
  /// and kind (low, then empty). Records it as shown.
  Future<(StockAlert, MedicineBoxItem?)> nextAlert(String routineId) async {
    final box = await cached();
    final item = box?.item(routineId);
    if (box == null || !box.started || item == null || !item.counted) return (StockAlert.none, null);
    final alert = stockAlertFor(item.dosesLeftWith(await pendingTaken(routineId, item.countedAt)));
    if (alert == StockAlert.none) return (StockAlert.none, item);
    final shown = await _shownAlerts();
    final mark = '${item.countedAt?.millisecondsSinceEpoch}:${alert.name}';
    if ((shown[routineId] as List?)?.contains(mark) ?? false) return (StockAlert.none, item);
    shown[routineId] = [...?(shown[routineId] as List?), mark];
    await _write(_alertsKey, shown);
    return (alert, item);
  }

  Future<Map<String, dynamic>> _shownAlerts() async => await _read(_alertsKey) ?? <String, dynamic>{};

  Future<void> _store(MedicineBox box) async {
    // Kept as the server sent it (re-read through MedicineBox.fromJson).
    await _write(_boxKey, {
      'startedAt': box.startedAt?.toUtc().toIso8601String(),
      'items': [
        for (final i in box.items)
          {
            'routineId': i.routineId,
            'medicineName': i.medicineName,
            'dosage': i.dosage,
            'doseAmount': i.doseAmount,
            'formName': i.formName,
            'unitsPerDose': i.unitsPerDose,
            'quantity': i.quantity,
            'countedAt': i.countedAt?.toUtc().toIso8601String(),
            'remaining': i.remaining,
          },
      ],
    });
  }

  Future<Map<String, dynamic>?> _read(String key) async {
    final row = await (_db.select(_db.cachedDocuments)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.json) as Map<String, dynamic>;
  }

  Future<void> _write(String key, Map<String, dynamic> value) => _db.into(_db.cachedDocuments).insertOnConflictUpdate(
        CachedDocumentsCompanion.insert(key: key, json: jsonEncode(value), cachedAt: DateTime.now()),
      );
}
