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
}
