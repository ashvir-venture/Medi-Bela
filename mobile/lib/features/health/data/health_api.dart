import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/health_models.dart';

class HealthApi {
  HealthApi(this._dio);

  final Dio _dio;

  Future<List<HealthReminderModel>> getReminders() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.healthReminders);
    return response.data!
        .map((r) => HealthReminderModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// [completedAt] should be when the user actually tapped complete —
  /// mirrors `MedicineScheduleApi.markDoseTaken`'s reasoning for the
  /// offline case.
  Future<HealthReminderModel> completeReminder(String id, {DateTime? completedAt}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.completeHealthReminder(id),
      data: {if (completedAt != null) 'completedAt': completedAt.toUtc().toIso8601String()},
    );
    return HealthReminderModel.fromJson(response.data!);
  }

  Future<List<HealthRecordModel>> getRecords() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.healthRecords);
    return response.data!
        .map((r) => HealthRecordModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<HealthRecordModel> createRecord({
    required String type,
    required String value,
    String? unit,
    String? notes,
    required DateTime recordedAt,
    String? clientId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.healthRecords,
      data: {
        if (clientId != null) 'clientId': clientId,
        'type': type,
        'value': value,
        if (unit != null && unit.isNotEmpty) 'unit': unit,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      },
    );
    return HealthRecordModel.fromJson(response.data!);
  }

  /// Published, pharmacist-reviewed AI suggestions for the current user
  /// only — see `ApiEndpoints.healthSuggestionsMine`.
  Future<List<HealthSuggestionModel>> getMySuggestions() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.healthSuggestionsMine);
    return response.data!
        .map((s) => HealthSuggestionModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}
