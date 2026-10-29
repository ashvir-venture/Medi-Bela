import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/inbox_models.dart';

class InboxApi {
  InboxApi(this._dio);

  final Dio _dio;

  /// 10 per page: user lists load 10 rows at a time ("Load more").
  Future<InboxPage> getPage({String? before, int limit = 10}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
      queryParameters: {'limit': limit, if (before != null) 'before': before},
    );
    return InboxPage.fromJson(response.data!);
  }

  Future<void> markRead(String id) async {
    await _dio.post<void>(ApiEndpoints.notificationRead(id));
  }

  Future<void> markAllRead() async {
    await _dio.post<void>(ApiEndpoints.notificationsReadAll);
  }
}
