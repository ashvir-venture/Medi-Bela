import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/assistant_models.dart';

class AssistantApi {
  AssistantApi(this._dio);

  final Dio _dio;

  Future<List<AssistantConversationSummary>> listConversations() async {
    final response =
        await _dio.get<List<dynamic>>(ApiEndpoints.assistantConversations);
    return [
      for (final item in response.data ?? const [])
        AssistantConversationSummary.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Creates an empty conversation owned by the signed-in user; returns its id.
  Future<String> createConversation() async {
    final response = await _dio
        .post<Map<String, dynamic>>(ApiEndpoints.assistantConversations);
    return response.data!['id'] as String;
  }

  Future<AssistantConversationDetail> getConversation(String id) async {
    final response = await _dio
        .get<Map<String, dynamic>>(ApiEndpoints.assistantConversation(id));
    return AssistantConversationDetail.fromJson(response.data!);
  }

  /// The server stores the message and builds the model context itself, so
  /// only the new message is sent. [clientMessageId] is created once per user
  /// message and re-sent unchanged on retry, so a retry never duplicates it.
  Future<AssistantReply> sendMessage({
    required String conversationId,
    required String message,
    required String clientMessageId,
    required String language, // 'EN' | 'BN'
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.assistantConversationMessages(conversationId),
      data: {
        'message': message,
        'clientMessageId': clientMessageId,
        'language': language,
      },
      // Model calls can take a while; the server itself gives up after 20s.
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    return AssistantReply.fromJson(response.data!);
  }

  /// Permanently deletes the conversation and its messages (own conversations only).
  Future<void> deleteConversation(String id) async {
    await _dio.delete<void>(ApiEndpoints.assistantConversation(id));
  }
}
