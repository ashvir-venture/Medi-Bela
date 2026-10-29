import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/prescription_models.dart';

/// Talks to the Phase 3A `/prescriptions` endpoints.
///
/// [clientId] is sent as the idempotency key so a retried upload (e.g.
/// after a dropped connection) can't create a duplicate prescription
/// server-side — see `Prescription.clientUploadId` on the backend.
/// Uploads a locally-created prescription draft, and lets the app pull
/// the pharmacist's review status once synced.
///
/// Written against the Phase 3A `/prescriptions` endpoints (see backend
/// `PrescriptionsController`). [uploadDraft]'s `clientId` doubles as an
/// idempotency key server-side, so a retried sync (e.g. after a dropped
/// connection mid-upload) can never create a duplicate prescription.
class PrescriptionApi {
  PrescriptionApi(this._dio);

  final Dio _dio;

  Future<String> uploadDraft({
    required String clientId,
    String? note,
    String? imageLocalPath,
    String? previousPrescriptionId,
  }) async {
    final formData = FormData.fromMap({
      'clientId': clientId,
      if (note != null && note.isNotEmpty) 'note': note,
      // Re-upload of a rejected prescription (the server checks it is ours).
      if (previousPrescriptionId != null) 'previousPrescriptionId': previousPrescriptionId,
      if (imageLocalPath != null && File(imageLocalPath).existsSync())
        'image': await MultipartFile.fromFile(imageLocalPath),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.prescriptions,
      data: formData,
    );
    return response.data!['id'] as String;
  }

  /// Full history, newest first — used to refresh local status (PENDING /
  /// COMPLETED / REJECTED) for drafts that have already synced.
  Future<List<PrescriptionSummaryModel>> getHistory() async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.prescriptionHistory,
    );
    return response.data!
        .map((p) => PrescriptionSummaryModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<PrescriptionDetailModel> getDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.prescriptionDetail(id),
    );
    return PrescriptionDetailModel.fromJson(response.data!);
  }
}
