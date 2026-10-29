import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/medicine_schedule_models.dart';

class MedicineScheduleApi {
  MedicineScheduleApi(this._dio);

  final Dio _dio;

  Future<List<MedicineRoutineModel>> getActiveRoutines() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.medicineRoutines);
    return response.data!
        .map((r) => MedicineRoutineModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<MedicineDoseModel>> getToday() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.medicineToday);
    return response.data!
        .map((d) => MedicineDoseModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Used to pre-cache enough future doses to schedule notifications
  /// ahead of time, not just for "today". [days] mirrors the backend's
  /// `?days=` cap (1–30).
  Future<List<MedicineDoseModel>> getUpcoming({int days = 7}) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.medicineUpcoming,
      queryParameters: {'days': days},
    );
    return response.data!
        .map((d) => MedicineDoseModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// [takenAt] should be the moment the user actually tapped "Taken" —
  /// important when this is called from the sync handler well after the
  /// fact (offline case). Defaults to "now" server-side if omitted.
  Future<MedicineDoseModel> markDoseTaken(String doseId, {DateTime? takenAt}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.markDoseTaken(doseId),
      data: {if (takenAt != null) 'takenAt': takenAt.toUtc().toIso8601String()},
    );
    return MedicineDoseModel.fromJson(response.data!);
  }

  // --- "My medicines" (online). [forUserId] = caregiver acting for a member. ---

  Future<List<ManagedRoutine>> getManagedRoutines({String? forUserId}) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.medicineRoutines,
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
    return response.data!.map((r) => ManagedRoutine.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<ManagedRoutine> createRoutine(Map<String, dynamic> body, {String? forUserId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.medicineRoutines,
      data: body,
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
    return ManagedRoutine.fromJson(response.data!);
  }

  Future<ManagedRoutine> updateRoutine(String id, Map<String, dynamic> body, {String? forUserId}) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.medicineRoutine(id),
      data: body,
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
    return ManagedRoutine.fromJson(response.data!);
  }

  Future<void> removeRoutine(String id, {String? forUserId}) async {
    await _dio.delete(
      ApiEndpoints.medicineRoutine(id),
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
  }

  Future<List<CatalogMedicineOption>> searchMedicines(String q) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.catalogMedicineSearch,
      queryParameters: {'q': q},
    );
    return response.data!.map((m) => CatalogMedicineOption.fromJson(m as Map<String, dynamic>)).toList();
  }
}
