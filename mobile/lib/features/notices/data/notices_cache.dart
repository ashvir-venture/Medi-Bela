import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notice_models.dart';

/// Offline copy of the user's active notices (small, read-only content).
///
/// Kept in SharedPreferences rather than Drift so no schema migration or code
/// generation is needed. Server-authoritative: every successful fetch
/// REPLACES the copy (an empty list clears it), and logout removes it.
class NoticesCache {
  static const _key = 'cache_notices_v1';

  Future<void> save(List<NoticeModel> notices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final n in notices) n.toJson()]));
  }

  /// `null` means "never cached" (distinct from a cached empty list).
  Future<List<NoticeModel>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return [
        for (final item in jsonDecode(raw) as List<dynamic>)
          NoticeModel.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      await prefs.remove(_key); // corrupt copy: drop it rather than crash Home
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
