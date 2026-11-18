import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/prescription_models.dart';
import '../../../core/network/direct_uploader.dart';

/// Talks to the Phase 3A `/prescriptions` endpoints.
///
/// [clientId] is sent as the idempotency key so a retried upload (e.g.
/// after a dropped connection) can't create a duplicate prescription
/// server-side — see `Prescription.clientUploadId` on the backend.
/// Uploads a locally-created prescription draft, and lets the app pull
/// the pharmacist's review status once synced.
///
/// Written against the Phase 3A `/prescriptions` endpoints (see backend
/// `PrescriptionsController`). [uploadPages]' `clientId` doubles as an
/// idempotency key server-side, so a retried sync (e.g. after a dropped
/// connection mid-upload) can never create a duplicate prescription.
class PrescriptionApi {
  PrescriptionApi(this._dio, {DirectUploader? uploader}) : _uploader = uploader ?? DirectUploader(_dio);

  final Dio _dio;
  final DirectUploader _uploader;

  /// Round 18 (client point 2): every page straight to Cloudinary, then one
  /// call that makes the prescription (so the pharmacist never sees half of
  /// it). `clientId` keeps a retried sync from making a second one.
  Future<String> uploadPages({
    required String clientId,
    required List<String> pages,
    String? note,
    String? previousPrescriptionId,
    String? forUserId,
  }) async {
    final ids = <String>[];
    for (final path in pages) {
      if (!File(path).existsSync()) continue;
      ids.add(await _uploader.upload(path, purpose: 'prescription', forUserId: forUserId));
    }
    if (ids.isEmpty) throw StateError('No photo to upload');
    final response = await _dio.post<Map<String, dynamic>>(
      '${ApiEndpoints.prescriptions}/pages',
      data: {
        'clientId': clientId,
        'pages': ids,
        if (note != null && note.isNotEmpty) 'note': note,
        'previousPrescriptionId': ?previousPrescriptionId,
      },
      queryParameters: {'forUserId': ?forUserId},
    );
    return response.data!['id'] as String;
  }

  /// Full history, newest first — used to refresh local status (PENDING /
  /// COMPLETED / REJECTED) for drafts that have already synced.
  Future<List<PrescriptionSummaryModel>> getHistory({String? forUserId}) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.prescriptionHistory,
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
    return response.data!
        .map((p) => PrescriptionSummaryModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<PrescriptionDetailModel> getDetail(String id, {String? forUserId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.prescriptionDetail(id),
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
    return PrescriptionDetailModel.fromJson(response.data!);
  }

  /// Confirm or Edit. [lines] holds only changed lines:
  /// `{id, scheduleTimes?, startDate?, mealTimingId?, intervalDays?, remove?}`.
  Future<PrescriptionDetailModel> confirm(
    String id, {
    required List<Map<String, dynamic>> lines,
    String? forUserId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.prescriptionConfirm(id),
      data: {'lines': lines},
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
    return PrescriptionDetailModel.fromJson(response.data!);
  }

  /// "Request edit" instead of confirming: back to the pharmacist with [note].
  Future<PrescriptionDetailModel> requestEdit(String id, {required String note, String? forUserId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.prescriptionRequestEdit(id),
      data: {'note': note},
      queryParameters: {if (forUserId != null) 'forUserId': forUserId},
    );
    return PrescriptionDetailModel.fromJson(response.data!);
  }

  /// A caregiver uploading for a family member. Online only: the member's
  /// prescriptions aren't kept in this phone's offline queue.
  Future<String> uploadForMember({required String forUserId, required List<String> pages}) =>
      uploadPages(clientId: const Uuid().v4(), pages: pages, forUserId: forUserId);
}
