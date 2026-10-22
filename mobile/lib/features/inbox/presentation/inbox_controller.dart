import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_mapper.dart';
import '../../../providers/core_providers.dart';
import '../data/inbox_api.dart';
import '../domain/inbox_models.dart';

class InboxState {
  const InboxState({
    this.items = const [],
    this.unreadCount = 0,
    this.nextCursor,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
  });

  final List<InboxItem> items;
  final int unreadCount;
  final String? nextCursor;
  final bool isLoading; // first page
  final bool isLoadingMore;
  final String? error; // first-page failure only

  bool get hasMore => nextCursor != null;

  InboxState copyWith({
    List<InboxItem>? items,
    int? unreadCount,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return InboxState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Server notifications are fetched live (not cached on the device): they are
/// a history of server events, and keeping other people's alerts out of the
/// local database keeps the on-device footprint of family data minimal.
class InboxController extends StateNotifier<InboxState> {
  InboxController(this._api) : super(const InboxState()) {
    load();
  }

  final InboxApi _api;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _api.getPage();
      state = InboxState(
        items: page.items,
        unreadCount: page.unreadCount,
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyErrorMessage(e));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _api.getPage(before: state.nextCursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        unreadCount: page.unreadCount,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
    } on DioException {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Optimistic; a failed call just leaves it unread on the next load.
  Future<void> markRead(String id) async {
    final index = state.items.indexWhere((i) => i.id == id);
    if (index == -1 || state.items[index].isRead) return;
    final updated = [...state.items];
    updated[index] = updated[index].copyWith(isRead: true);
    state = state.copyWith(
      items: updated,
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
    try {
      await _api.markRead(id);
    } on DioException {/* retried implicitly on next load */}
  }

  Future<void> markAllRead() async {
    state = state.copyWith(
      items: [for (final i in state.items) i.copyWith(isRead: true)],
      unreadCount: 0,
    );
    try {
      await _api.markAllRead();
    } on DioException {/* server state corrected on next load */}
  }
}

final inboxApiProvider = Provider<InboxApi>((ref) {
  return InboxApi(ref.watch(dioClientProvider).dio);
});

final inboxControllerProvider =
    StateNotifierProvider.autoDispose<InboxController, InboxState>((ref) {
  return InboxController(ref.watch(inboxApiProvider));
});

/// Badge count for the Home bell. Offline/any failure just shows no badge.
final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  try {
    final page = await ref.watch(inboxApiProvider).getPage(limit: 1);
    return page.unreadCount;
  } catch (_) {
    return 0;
  }
});
