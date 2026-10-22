import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../data/assistant_api.dart';
import '../domain/assistant_models.dart';

enum DeleteOutcome { deleted, offline, failed }

class AssistantConversationsState {
  const AssistantConversationsState({
    this.items = const [],
    this.isLoading = true,
    this.loadFailed = false,
    this.deletingIds = const {},
  });

  final List<AssistantConversationSummary> items;
  final bool isLoading;
  final bool loadFailed;

  /// Conversations whose deletion request is in flight. Sending to these is blocked.
  final Set<String> deletingIds;

  AssistantConversationsState copyWith({
    List<AssistantConversationSummary>? items,
    bool? isLoading,
    bool? loadFailed,
    Set<String>? deletingIds,
  }) {
    return AssistantConversationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      loadFailed: loadFailed ?? this.loadFailed,
      deletingIds: deletingIds ?? this.deletingIds,
    );
  }
}

/// The saved conversations of the signed-in user, and the only place that
/// deletes them (used by both the list and the chat screen). The server is the
/// source of truth: a conversation leaves the list only once the server has
/// confirmed the deletion.
class AssistantConversationsController
    extends StateNotifier<AssistantConversationsState> {
  AssistantConversationsController(this._api)
      : super(const AssistantConversationsState()) {
    load();
  }

  final AssistantApi _api;

  bool isDeleting(String id) => state.deletingIds.contains(id);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, loadFailed: false);
    try {
      final items = await _api.listConversations();
      if (!mounted) return;
      state = state.copyWith(items: items, isLoading: false);
    } on DioException {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, loadFailed: true);
    }
  }

  /// Re-reads the list without flashing a spinner (e.g. after returning from a chat).
  Future<void> refresh() async {
    try {
      final items = await _api.listConversations();
      if (!mounted) return;
      state = state.copyWith(items: items, loadFailed: false);
    } on DioException {
      // Keep what is already shown; the next load() will report a real failure.
    }
  }

  Future<DeleteOutcome> delete(String id) async {
    if (isDeleting(id)) return DeleteOutcome.failed;
    state = state.copyWith(deletingIds: {...state.deletingIds, id});
    try {
      await _api.deleteConversation(id);
      _finishDelete(id, removed: true);
      return DeleteOutcome.deleted;
    } on DioException catch (e) {
      // 404 = already gone (e.g. deleted from another device): same end state.
      if (e.response?.statusCode == 404) {
        _finishDelete(id, removed: true);
        return DeleteOutcome.deleted;
      }
      // Failed: the conversation stays in the list.
      _finishDelete(id, removed: false);
      final offline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
      return offline ? DeleteOutcome.offline : DeleteOutcome.failed;
    }
  }

  void _finishDelete(String id, {required bool removed}) {
    if (!mounted) return;
    state = state.copyWith(
      items: removed ? state.items.where((c) => c.id != id).toList() : null,
      deletingIds: {...state.deletingIds}..remove(id),
    );
  }
}

final assistantApiProvider = Provider<AssistantApi>((ref) {
  return AssistantApi(ref.watch(dioClientProvider).dio);
});

final assistantConversationsProvider = StateNotifierProvider.autoDispose<
    AssistantConversationsController, AssistantConversationsState>((ref) {
  return AssistantConversationsController(ref.watch(assistantApiProvider));
});
