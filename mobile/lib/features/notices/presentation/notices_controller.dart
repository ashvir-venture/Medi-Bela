import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../data/notices_cache.dart';
import '../domain/notice_models.dart';

final noticesCacheProvider = Provider<NoticesCache>((ref) => NoticesCache());

/// Online: fetch, show, and replace the offline copy (server-authoritative —
/// an unpublished/expired/deleted notice disappears on the next successful
/// fetch). Offline or server down: fall back to the last copy so Home and the
/// notices screen still work. A 401 is NOT a reason to show cached content.
/// Pull-to-refresh calls `ref.invalidate(myNoticesProvider)`.
final myNoticesProvider = FutureProvider<List<NoticeModel>>((ref) async {
  final cache = ref.watch(noticesCacheProvider);
  List<NoticeModel> notices;
  try {
    notices = await ref.watch(noticesApiProvider).getMine();
    await cache.save(notices);
  } on DioException catch (e) {
    final cached = e.response?.statusCode == 401 ? null : await cache.load();
    if (cached == null) rethrow;
    notices = cached;
  }
  // The server already hides unpublished/expired notices; this also hides a
  // cached copy that has expired since it was saved.
  return notices.where((n) => !n.isExpired).toList();
});
