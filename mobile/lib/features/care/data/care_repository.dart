import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../domain/care_models.dart';
import 'care_api.dart';

const careDocKey = 'care';
const recordsDocKey = 'records';
const careLookupsDocKey = 'care_lookups';

/// My care and health records on the phone: the last server answers kept
/// whole in cached_documents (like the medicine box), so the condition pages,
/// the records page, their reminders and the PDF work offline. Changes need
/// the internet; each one pulls the fresh answer. The caregiver's view of a
/// member ([forUserId]) is online only and never cached.
class CareRepository {
  CareRepository({required CareApi api, required AppDatabase database})
      : _api = api,
        _db = database;

  final CareApi _api;
  final AppDatabase _db;

  CareApi get api => _api;

  // --- reads ---

  Stream<CareOverview> watchCare() => _watch(careDocKey).map((j) => j == null ? CareOverview.empty : CareOverview.fromJson(j));

  Stream<RecordsOverview> watchRecords() =>
      _watch(recordsDocKey).map((j) => j == null ? RecordsOverview.empty : RecordsOverview.fromJson(j));

  Future<CareOverview> care() async {
    final j = await _read(careDocKey);
    return j == null ? CareOverview.empty : CareOverview.fromJson(j);
  }

  Future<RecordsOverview> records() async {
    final j = await _read(recordsDocKey);
    return j == null ? RecordsOverview.empty : RecordsOverview.fromJson(j);
  }

  /// The condition and test lists: online first, the last copy offline.
  Future<CareLookups> lookups() async {
    try {
      final all = await _api.lookups();
      final picked = {'conditions': all['conditions'] ?? [], 'testKinds': all['testKinds'] ?? []};
      await _write(careLookupsDocKey, picked);
      return CareLookups.fromJson(picked);
    } catch (_) {
      final j = await _read(careLookupsDocKey);
      if (j == null) rethrow;
      return CareLookups.fromJson(j);
    }
  }

  // --- refresh (SessionServices.refresh and after every change) ---

  Future<CareOverview> refreshCare() async {
    final j = await _api.overview();
    await _write(careDocKey, j);
    return CareOverview.fromJson(j);
  }

  Future<RecordsOverview> refreshRecords() async {
    final j = await _api.records();
    await _write(recordsDocKey, j);
    return RecordsOverview.fromJson(j);
  }

  Future<void> refreshAll() async {
    await refreshCare();
    await refreshRecords();
  }

  // --- changes (own; the caregiver screens call [api] with forUserId) ---

  Future<void> setConditions(List<String> codes) async {
    await _api.setConditions(codes);
    await refreshCare();
  }

  Future<void> skipStep() async {
    await _api.skipStep();
    await refreshCare();
  }

  Future<void> updateLimits(Map<String, dynamic> changes) async {
    await _api.updateLimits(changes);
    await refreshCare();
  }

  Future<void> updateSetting(String code, Map<String, dynamic> changes) async {
    await _api.updateSetting(code, changes);
    await refreshCare();
  }

  /// A habit or night tick: shown at once, undone if the server refuses.
  Future<void> setTick(String key, DateTime day, bool done) async {
    final dayText = isoDate(day);
    await _patchCare((j) {
      final ticks = [for (final t in (j['ticks'] as List? ?? [])) Map<String, dynamic>.from(t as Map)]
        ..removeWhere((t) => t['key'] == key && t['day'] == dayText);
      if (done) ticks.add({'key': key, 'day': dayText});
      j['ticks'] = ticks;
    });
    try {
      await _api.setTick(key, dayText, done);
    } catch (_) {
      await _patchCare((j) {
        final ticks = [for (final t in (j['ticks'] as List? ?? [])) Map<String, dynamic>.from(t as Map)]
          ..removeWhere((t) => t['key'] == key && t['day'] == dayText);
        if (!done) ticks.add({'key': key, 'day': dayText});
        j['ticks'] = ticks;
      });
      rethrow;
    }
  }

  Future<void> addLog(Map<String, dynamic> body) async {
    await _api.addLog(body);
    await refreshCare();
  }

  Future<void> deleteLog(String id) async {
    await _api.deleteLog(id);
    await refreshCare();
  }

  Future<void> addQuestion(String text) async {
    await _api.addQuestion(text);
    await refreshCare();
  }

  Future<void> deleteQuestion(String id) async {
    await _api.deleteQuestion(id);
    await refreshCare();
  }

  Future<bool> alertFamily() => _api.alertFamily();

  Future<Map<String, dynamic>> saveAppointment(Map<String, dynamic> body, {String? id}) async {
    final saved = await _api.saveAppointment(body, id: id);
    await refreshRecords();
    return saved;
  }

  Future<void> deleteAppointment(String id) async {
    await _api.deleteAppointment(id);
    await refreshRecords();
  }

  Future<Map<String, dynamic>> saveTest(Map<String, dynamic> body, {String? id}) async {
    final saved = await _api.saveTest(body, id: id);
    await refreshRecords();
    return saved;
  }

  Future<void> deleteTest(String id) async {
    await _api.deleteTest(id);
    await refreshRecords();
  }

  Future<Map<String, dynamic>> savePrescription(Map<String, dynamic> body, {String? id}) async {
    final saved = await _api.savePrescription(body, id: id);
    await refreshRecords();
    return saved;
  }

  Future<void> deletePrescription(String id) async {
    await _api.deletePrescription(id);
    await refreshRecords();
  }

  Future<void> addPhoto({required String path, String? testId, String? prescriptionId}) async {
    await _api.addPhoto(path: path, testId: testId, prescriptionId: prescriptionId);
    await refreshRecords();
  }

  Future<void> deletePhoto(String id) async {
    await _api.deletePhoto(id);
    await refreshRecords();
  }

  // --- cache ---

  Future<void> _patchCare(void Function(Map<String, dynamic> j) change) async {
    final j = await _read(careDocKey) ?? <String, dynamic>{};
    change(j);
    await _write(careDocKey, j);
  }

  Stream<Map<String, dynamic>?> _watch(String key) => (_db.select(_db.cachedDocuments)..where((t) => t.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row == null ? null : Map<String, dynamic>.from(jsonDecode(row.json) as Map));

  Future<Map<String, dynamic>?> _read(String key) async {
    final row = await (_db.select(_db.cachedDocuments)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : Map<String, dynamic>.from(jsonDecode(row.json) as Map);
  }

  Future<void> _write(String key, Map<String, dynamic> value) => _db.into(_db.cachedDocuments).insertOnConflictUpdate(
        CachedDocumentsCompanion.insert(key: key, json: jsonEncode(value), cachedAt: DateTime.now()),
      );
}
