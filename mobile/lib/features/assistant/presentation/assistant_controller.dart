import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/localization/locale_controller.dart';
import '../data/assistant_api.dart';
import '../domain/assistant_models.dart';
import 'assistant_conversations_controller.dart';

enum AssistantError {
  none,
  unavailable,
  tooManyRequests,
  offline,
  loadFailed,
  notFound,
}

class AssistantState {
  const AssistantState({
    this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error = AssistantError.none,
    this.pendingText,
    this.pendingClientId,
    this.isClosed = false,
    this.userMessageCount = 0,
    this.maxUserMessages = 10,
  });

  /// Null until the first message of a new conversation is sent.
  final String? conversationId;
  final List<ChatMessage> messages;

  /// A saved conversation is being loaded from the server.
  final bool isLoading;
  final bool isSending;
  final AssistantError error;

  /// The user message that has no reply yet (kept so Retry can resend it with
  /// the same idempotency key, without adding a duplicate bubble or message).
  final String? pendingText;
  final String? pendingClientId;

  /// The 10-message limit was reached: the conversation is read-only.
  final bool isClosed;
  final int userMessageCount;
  final int maxUserMessages;

  AssistantState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    AssistantError? error,
    String? pendingText,
    String? pendingClientId,
    bool clearPending = false,
    bool? isClosed,
    int? userMessageCount,
    int? maxUserMessages,
  }) {
    return AssistantState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error ?? this.error,
      pendingText: clearPending ? null : (pendingText ?? this.pendingText),
      pendingClientId:
          clearPending ? null : (pendingClientId ?? this.pendingClientId),
      isClosed: isClosed ?? this.isClosed,
      userMessageCount: userMessageCount ?? this.userMessageCount,
      maxUserMessages: maxUserMessages ?? this.maxUserMessages,
    );
  }
}

const _uuid = Uuid();

/// One chat screen's conversation. The server stores every message, enforces
/// the 10-message limit and builds the model context; this class only shows
/// what the server has and re-sends unanswered messages safely.
class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(
    this._api,
    this._language,
    this._conversations,
    String? conversationId,
  ) : super(AssistantState(
          conversationId: conversationId,
          isLoading: conversationId != null,
        )) {
    if (conversationId != null) load();
  }

  final AssistantApi _api;
  final String Function() _language; // 'EN' | 'BN', read at send time
  final AssistantConversationsController _conversations;

  /// Loads the saved conversation (messages, status, counters) from the server.
  Future<void> load() async {
    final id = state.conversationId;
    if (id == null) return;
    state = state.copyWith(isLoading: true, error: AssistantError.none);
    try {
      final detail = await _api.getConversation(id);
      if (!mounted) return;
      // An unanswered last user message (reply failed, or the app was closed
      // before it arrived) is offered for retry with its original key.
      final last = detail.messages.isNotEmpty ? detail.messages.last : null;
      final unanswered = last != null && last.fromUser ? last : null;
      state = AssistantState(
        conversationId: id,
        messages: detail.messages,
        isClosed: detail.isClosed,
        userMessageCount: detail.userMessageCount,
        maxUserMessages: detail.maxUserMessages,
        pendingText: unanswered?.text,
        pendingClientId: unanswered?.clientMessageId,
        error: unanswered != null && unanswered.clientMessageId != null
            ? AssistantError.unavailable
            : AssistantError.none,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.response?.statusCode == 404
            ? AssistantError.notFound
            : AssistantError.loadFailed,
      );
    }
  }

  bool get _blocked {
    final id = state.conversationId;
    return state.isSending ||
        state.isLoading ||
        state.isClosed ||
        state.error == AssistantError.notFound ||
        // The server needs the previous message answered first: Retry it.
        state.pendingText != null ||
        (id != null && _conversations.isDeleting(id));
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _blocked) return;

    final clientId = _uuid.v4();
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(fromUser: true, text: trimmed, clientMessageId: clientId),
      ],
      error: AssistantError.none,
      clearPending: true,
    );
    await _request(trimmed, clientId);
  }

  /// Re-sends the unanswered message with the SAME key: the server will not
  /// store or count it twice, and returns the existing reply if there already is one.
  Future<void> retry() async {
    final text = state.pendingText;
    final clientId = state.pendingClientId;
    if (text == null || clientId == null || state.isSending) return;
    state = state.copyWith(error: AssistantError.none);
    await _request(text, clientId);
  }

  Future<void> _request(String text, String clientId) async {
    state = state.copyWith(isSending: true);
    try {
      var id = state.conversationId;
      if (id == null) {
        id = await _api.createConversation();
        if (!mounted) return;
        state = state.copyWith(conversationId: id);
      }
      final reply = await _api.sendMessage(
        conversationId: id,
        message: text,
        clientMessageId: clientId,
        language: _language(),
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            fromUser: false,
            text: reply.reply,
            kind: reply.kind,
            disclaimer: reply.disclaimer,
          ),
        ],
        isSending: false,
        clearPending: true,
        isClosed: reply.isClosed,
        userMessageCount: reply.userMessageCount,
        maxUserMessages: reply.maxUserMessages,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 404) {
        // Deleted (e.g. from another device) while we were talking to it.
        state = state.copyWith(
          isSending: false,
          error: AssistantError.notFound,
          clearPending: true,
        );
        return;
      }
      if (status == 409) {
        // Closed / reply still pending on the server: show what the server has.
        state = state.copyWith(isSending: false, clearPending: true);
        await load();
        return;
      }
      state = state.copyWith(
        isSending: false,
        error: _classify(e),
        pendingText: text,
        pendingClientId: clientId,
      );
    }
  }

  /// Deletes this conversation through the shared list controller. On success
  /// the messages are cleared; the screen then leaves the conversation.
  Future<DeleteOutcome> deleteConversation() async {
    final id = state.conversationId;
    if (id == null) return DeleteOutcome.deleted; // never saved: nothing to delete
    final outcome = await _conversations.delete(id);
    if (outcome == DeleteOutcome.deleted && mounted) {
      state = AssistantState(
        conversationId: id,
        error: AssistantError.notFound,
      );
    }
    return outcome;
  }

  AssistantError _classify(DioException e) {
    if (e.response?.statusCode == 429) return AssistantError.tooManyRequests;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return AssistantError.offline;
    }
    return AssistantError.unavailable;
  }
}

/// Keyed by the saved conversation to open, or null for a new conversation.
final assistantControllerProvider = StateNotifierProvider.autoDispose
    .family<AssistantController, AssistantState, String?>((ref, conversationId) {
  return AssistantController(
    ref.watch(assistantApiProvider),
    () => ref.read(localeControllerProvider).languageCode == 'bn' ? 'BN' : 'EN',
    ref.watch(assistantConversationsProvider.notifier),
    conversationId,
  );
});
