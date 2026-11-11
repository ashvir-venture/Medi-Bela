import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../providers/core_providers.dart';
import '../domain/care_models.dart';
import 'care_providers.dart';

const _uuid = Uuid();

/// Every change on the condition pages, for me (the cached repository) or,
/// for a caregiver, the member (online API, then reload the member's data).
class CareActions {
  CareActions(this.ref, this.who);

  final WidgetRef ref;
  final CareSubject who;

  String? get _for => who.memberId;

  Future<void> _member(Future<void> Function() call) async {
    await call();
    invalidateMember(ref, who);
  }

  Future<void> setTick(String key, DateTime day, bool done) => who.isMember
      ? _member(() => ref.read(careApiProvider).setTick(key, isoDate(day), done, forUserId: _for))
      : ref.read(careRepositoryProvider).setTick(key, day, done);

  Future<void> updateSetting(String code, Map<String, dynamic> changes) => who.isMember
      ? _member(() => ref.read(careApiProvider).updateSetting(code, changes, forUserId: _for))
      : ref.read(careRepositoryProvider).updateSetting(code, changes);

  Future<void> addLog(CareLogKind kind, Map<String, dynamic> data, {String? condition}) {
    final body = {
      'kind': careLogKindApi(kind),
      'conditionCode': ?condition,
      'data': data,
      'loggedAt': DateTime.now().toUtc().toIso8601String(),
      'clientId': _uuid.v4(),
    };
    return who.isMember
        ? _member(() => ref.read(careApiProvider).addLog(body, forUserId: _for))
        : ref.read(careRepositoryProvider).addLog(body);
  }

  Future<void> deleteLog(String id) => who.isMember
      ? _member(() => ref.read(careApiProvider).deleteLog(id, forUserId: _for))
      : ref.read(careRepositoryProvider).deleteLog(id);

  Future<void> addQuestion(String text) => who.isMember
      ? _member(() => ref.read(careApiProvider).addQuestion(text, forUserId: _for))
      : ref.read(careRepositoryProvider).addQuestion(text);

  Future<void> deleteQuestion(String id) => who.isMember
      ? _member(() => ref.read(careApiProvider).deleteQuestion(id, forUserId: _for))
      : ref.read(careRepositoryProvider).deleteQuestion(id);

  Future<Map<String, dynamic>> saveAppointment(Map<String, dynamic> body, {String? id}) async {
    if (!who.isMember) return ref.read(careRepositoryProvider).saveAppointment(body, id: id);
    final saved = await ref.read(careApiProvider).saveAppointment(body, id: id, forUserId: _for);
    invalidateMember(ref, who);
    return saved;
  }

  Future<void> deleteAppointment(String id) => who.isMember
      ? _member(() => ref.read(careApiProvider).deleteAppointment(id, forUserId: _for))
      : ref.read(careRepositoryProvider).deleteAppointment(id);

  Future<Map<String, dynamic>> saveTest(Map<String, dynamic> body, {String? id}) async {
    if (!who.isMember) return ref.read(careRepositoryProvider).saveTest(body, id: id);
    final saved = await ref.read(careApiProvider).saveTest(body, id: id, forUserId: _for);
    invalidateMember(ref, who);
    return saved;
  }

  Future<void> deleteTest(String id) => who.isMember
      ? _member(() => ref.read(careApiProvider).deleteTest(id, forUserId: _for))
      : ref.read(careRepositoryProvider).deleteTest(id);

  Future<Map<String, dynamic>> savePrescription(Map<String, dynamic> body, {String? id}) async {
    if (!who.isMember) return ref.read(careRepositoryProvider).savePrescription(body, id: id);
    final saved = await ref.read(careApiProvider).savePrescription(body, id: id, forUserId: _for);
    invalidateMember(ref, who);
    return saved;
  }

  Future<void> deletePrescription(String id) => who.isMember
      ? _member(() => ref.read(careApiProvider).deletePrescription(id, forUserId: _for))
      : ref.read(careRepositoryProvider).deletePrescription(id);

  Future<void> addPhoto({required String path, String? testId, String? prescriptionId}) => who.isMember
      ? _member(() => ref.read(careApiProvider).addPhoto(path: path, testId: testId, prescriptionId: prescriptionId, forUserId: _for))
      : ref.read(careRepositoryProvider).addPhoto(path: path, testId: testId, prescriptionId: prescriptionId);

  Future<void> deletePhoto(String id) => who.isMember
      ? _member(() => ref.read(careApiProvider).deletePhoto(id, forUserId: _for))
      : ref.read(careRepositoryProvider).deletePhoto(id);

  /// Readings refresh (own records are offline-first; the member's online).
  void readingsChanged() => invalidateMember(ref, who);
}
