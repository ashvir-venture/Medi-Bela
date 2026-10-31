import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The upcoming full-screen reminders, shared with Android (MainActivity /
/// FullScreenAlarms.kt): `{"<notification id>": {"at": ms, "route": ...}}`
/// in SharedPreferences, so any isolate (the app, or Done / Later with the
/// app closed) can add or drop one. Android schedules an alarm per entry and,
/// when "Display over other apps" is allowed, opens [route] over whatever is
/// on screen. Each ringing reminder has one entry under its notification id,
/// so cancelling the notification cancels its full screen too.
class FullScreenAlarms {
  FullScreenAlarms._();

  static const _key = 'fullscreen_alarms';
  static const _channel = MethodChannel('com.carebridge.app/reminder_status');

  static bool get _enabled => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> add(int id, DateTime at, String route) =>
      _update((map) => map['$id'] = {'at': at.millisecondsSinceEpoch, 'route': route});

  static Future<void> remove(int id) => _update((map) => map.remove('$id'));

  static Future<void> clear() => _update((map) => map.clear());

  static Future<void> _update(void Function(Map<String, dynamic> map) change) async {
    if (!_enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Another isolate may have written since this one last read.
      await prefs.reload();
      final raw = prefs.getString(_key);
      final map = raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final before = jsonEncode(map);
      change(map);
      final now = DateTime.now().millisecondsSinceEpoch;
      // Long past ones are of no use any more.
      map.removeWhere((_, v) => v is! Map || (v['at'] as int? ?? 0) < now - const Duration(hours: 2).inMilliseconds);
      final after = jsonEncode(map);
      if (after == before) return;
      await prefs.setString(_key, after);
      await _channel.invokeMethod<bool>('syncFullScreenAlarms');
    } on MissingPluginException {
      // A background isolate: Android picks the list up at the next alarm or app start.
    } catch (_) {
      // Never let the full screen break the regular reminder.
    }
  }
}
