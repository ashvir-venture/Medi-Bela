import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/notice_models.dart';

class NoticesApi {
  NoticesApi(this._dio);

  final Dio _dio;

  /// Published, non-expired, audience-matched notices only — see
  /// `ApiEndpoints.noticesMine`.
  Future<List<NoticeModel>> getMine() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.noticesMine);
    return response.data!.map((n) => NoticeModel.fromJson(n as Map<String, dynamic>)).toList();
  }

  /// Round 17: send this notice to my family's Family inbox.
  Future<({int sharedWith, bool alreadyShared})> shareWithFamily(String id) async {
    final response = await _dio.post<Map<String, dynamic>>(ApiEndpoints.noticeShareFamily(id));
    final data = response.data ?? const {};
    return (
      sharedWith: (data['sharedWith'] as num?)?.toInt() ?? 0,
      alreadyShared: data['alreadyShared'] == true,
    );
  }

  /// A notice someone in my family shared with me (also outside my division).
  Future<NoticeModel> getShared(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.noticeShared(id));
    return NoticeModel.fromJson(response.data!);
  }
}
