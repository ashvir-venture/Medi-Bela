import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';

/// GET/PUT /care (Round 15) and /records (Round 16). `forUserId` = the
/// caregiver acting for that member (online only, like other caregiver screens).
class CareApi {
  CareApi(this._dio);

  final Dio _dio;

  Map<String, dynamic> _for(String? forUserId) => {'forUserId': ?forUserId};

  Future<Map<String, dynamic>> lookups() async =>
      (await _dio.get<Map<String, dynamic>>(ApiEndpoints.lookups)).data!;

  // --- My care ---

  Future<Map<String, dynamic>> overview({String? forUserId}) async =>
      (await _dio.get<Map<String, dynamic>>(ApiEndpoints.care, queryParameters: _for(forUserId))).data!;

  Future<void> setConditions(List<String> codes, {String? forUserId}) =>
      _dio.put<void>(ApiEndpoints.careConditions, data: {'codes': codes}, queryParameters: _for(forUserId));

  Future<void> skipStep() => _dio.post<void>(ApiEndpoints.careStepSkip);

  Future<void> updateLimits(Map<String, dynamic> changes, {String? forUserId}) =>
      _dio.put<void>(ApiEndpoints.careLimits, data: changes, queryParameters: _for(forUserId));

  Future<void> updateSetting(String code, Map<String, dynamic> changes, {String? forUserId}) =>
      _dio.put<void>(ApiEndpoints.careSettings(code), data: changes, queryParameters: _for(forUserId));

  Future<void> setTick(String key, String day, bool done, {String? forUserId}) => _dio.put<void>(
        ApiEndpoints.careTicks,
        data: {'key': key, 'day': day, 'done': done},
        queryParameters: _for(forUserId),
      );

  Future<void> addLog(Map<String, dynamic> body, {String? forUserId}) =>
      _dio.post<void>(ApiEndpoints.careLogs, data: body, queryParameters: _for(forUserId));

  Future<void> deleteLog(String id, {String? forUserId}) =>
      _dio.delete<void>(ApiEndpoints.careLog(id), queryParameters: _for(forUserId));

  Future<void> addQuestion(String text, {String? forUserId}) =>
      _dio.post<void>(ApiEndpoints.careQuestions, data: {'text': text}, queryParameters: _for(forUserId));

  Future<void> deleteQuestion(String id, {String? forUserId}) =>
      _dio.delete<void>(ApiEndpoints.careQuestion(id), queryParameters: _for(forUserId));

  /// The emergency sheet's "Alert family": true when the caregiver was told.
  Future<bool> alertFamily() async {
    final res = await _dio.post<Map<String, dynamic>>(ApiEndpoints.careAlertFamily);
    return res.data?['notified'] == true;
  }

  // --- Health records 2.0 ---

  Future<Map<String, dynamic>> records({String? forUserId}) async =>
      (await _dio.get<Map<String, dynamic>>(ApiEndpoints.records, queryParameters: _for(forUserId))).data!;

  Future<Map<String, dynamic>> searchDoctors(String q, {String? forUserId}) async => (await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.recordsDoctorSearch,
        queryParameters: {'q': q, ..._for(forUserId)},
      ))
          .data!;

  Future<Map<String, dynamic>> saveAppointment(Map<String, dynamic> body, {String? id, String? forUserId}) async {
    final res = id == null
        ? await _dio.post<Map<String, dynamic>>(ApiEndpoints.recordsAppointments, data: body, queryParameters: _for(forUserId))
        : await _dio.patch<Map<String, dynamic>>(ApiEndpoints.recordsAppointment(id), data: body, queryParameters: _for(forUserId));
    return res.data!;
  }

  Future<void> deleteAppointment(String id, {String? forUserId}) =>
      _dio.delete<void>(ApiEndpoints.recordsAppointment(id), queryParameters: _for(forUserId));

  Future<Map<String, dynamic>> saveTest(Map<String, dynamic> body, {String? id, String? forUserId}) async {
    final res = id == null
        ? await _dio.post<Map<String, dynamic>>(ApiEndpoints.recordsTests, data: body, queryParameters: _for(forUserId))
        : await _dio.patch<Map<String, dynamic>>(ApiEndpoints.recordsTest(id), data: body, queryParameters: _for(forUserId));
    return res.data!;
  }

  Future<void> deleteTest(String id, {String? forUserId}) =>
      _dio.delete<void>(ApiEndpoints.recordsTest(id), queryParameters: _for(forUserId));

  Future<Map<String, dynamic>> savePrescription(Map<String, dynamic> body, {String? id, String? forUserId}) async {
    final res = id == null
        ? await _dio.post<Map<String, dynamic>>(ApiEndpoints.recordsPrescriptions, data: body, queryParameters: _for(forUserId))
        : await _dio.patch<Map<String, dynamic>>(ApiEndpoints.recordsPrescription(id), data: body, queryParameters: _for(forUserId));
    return res.data!;
  }

  Future<void> deletePrescription(String id, {String? forUserId}) =>
      _dio.delete<void>(ApiEndpoints.recordsPrescription(id), queryParameters: _for(forUserId));

  /// One page photo (already shrunk) of a test report or a record prescription.
  Future<void> addPhoto({required String path, String? testId, String? prescriptionId, String? forUserId}) async {
    final form = FormData.fromMap({'image': await MultipartFile.fromFile(path)});
    final url = testId != null ? ApiEndpoints.recordsTestPhotos(testId) : ApiEndpoints.recordsPrescriptionPhotos(prescriptionId!);
    await _dio.post<void>(url, data: form, queryParameters: _for(forUserId));
  }

  Future<void> deletePhoto(String id, {String? forUserId}) =>
      _dio.delete<void>(ApiEndpoints.recordsPhoto(id), queryParameters: _for(forUserId));
}
