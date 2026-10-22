/// One reply from `POST /assistant/conversations/:id/messages`.
///
/// [kind] is decided by the server: `ANSWER` (model reply), `EMERGENCY`
/// (fixed urgent-care message) or `REFUSAL` (fixed "can't help with that,
/// ask a professional" message). [disclaimer] is always added server-side.
/// [conversationStatus] becomes `CLOSED` once the 10th user message has been
/// answered; the conversation is then read-only.
class AssistantReply {
  const AssistantReply({
    required this.reply,
    required this.kind,
    required this.disclaimer,
    required this.conversationStatus,
    required this.userMessageCount,
    required this.maxUserMessages,
  });

  final String reply;
  final String kind;
  final String disclaimer;
  final String conversationStatus;
  final int userMessageCount;
  final int maxUserMessages;

  bool get isClosed => conversationStatus == 'CLOSED';

  factory AssistantReply.fromJson(Map<String, dynamic> json) {
    return AssistantReply(
      reply: json['reply'] as String,
      kind: json['kind'] as String? ?? 'ANSWER',
      disclaimer: json['disclaimer'] as String? ?? '',
      conversationStatus: json['conversationStatus'] as String? ?? 'OPEN',
      userMessageCount: json['userMessageCount'] as int? ?? 0,
      maxUserMessages: json['maxUserMessages'] as int? ?? 10,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.fromUser,
    required this.text,
    this.kind = 'ANSWER',
    this.disclaimer,
    this.clientMessageId,
  });

  final bool fromUser;
  final String text;
  final String kind;
  final String? disclaimer;

  /// User messages only: the idempotency key the message was (or will be) sent with.
  final String? clientMessageId;

  bool get isEmergency => !fromUser && kind == 'EMERGENCY';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final fromUser = json['role'] == 'user';
    return ChatMessage(
      fromUser: fromUser,
      text: json['content'] as String,
      kind: json['kind'] as String? ?? 'ANSWER',
      disclaimer: json['disclaimer'] as String?,
      clientMessageId: json['clientMessageId'] as String?,
    );
  }
}

/// A row of the conversation list (`GET /assistant/conversations`).
class AssistantConversationSummary {
  const AssistantConversationSummary({
    required this.id,
    required this.status,
    required this.userMessageCount,
    required this.maxUserMessages,
    required this.preview,
    required this.updatedAt,
  });

  final String id;
  final String status;
  final int userMessageCount;
  final int maxUserMessages;

  /// First user message, already flattened and clipped by the server.
  final String preview;
  final DateTime updatedAt;

  bool get isClosed => status == 'CLOSED';

  factory AssistantConversationSummary.fromJson(Map<String, dynamic> json) {
    return AssistantConversationSummary(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'OPEN',
      userMessageCount: json['userMessageCount'] as int? ?? 0,
      maxUserMessages: json['maxUserMessages'] as int? ?? 10,
      preview: json['preview'] as String? ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }
}

/// One saved conversation with all of its messages, oldest first
/// (`GET /assistant/conversations/:id`).
class AssistantConversationDetail {
  const AssistantConversationDetail({
    required this.id,
    required this.status,
    required this.userMessageCount,
    required this.maxUserMessages,
    required this.messages,
  });

  final String id;
  final String status;
  final int userMessageCount;
  final int maxUserMessages;
  final List<ChatMessage> messages;

  bool get isClosed => status == 'CLOSED';

  factory AssistantConversationDetail.fromJson(Map<String, dynamic> json) {
    return AssistantConversationDetail(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'OPEN',
      userMessageCount: json['userMessageCount'] as int? ?? 0,
      maxUserMessages: json['maxUserMessages'] as int? ?? 10,
      messages: [
        for (final m in (json['messages'] as List<dynamic>? ?? const []))
          ChatMessage.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}
