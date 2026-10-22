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
}
