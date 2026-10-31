import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reminder timings, set on the server in .env (backend
/// common/config/reminder-timing.ts) and read from GET /app-config on every
/// refresh (SessionServices). Kept in SharedPreferences so background
/// isolates (Done / Later with the app closed) use the same values; the
/// defaults below are the server's defaults, used until the first answer.
class ReminderTiming {
  const ReminderTiming({
    this.repeatMinutes = 15,
    this.rings = 4,
    this.ringMinutes = 2,
    this.takenClosesBeforeNextMinutes = 60,
    this.testReminderDays = 3,
    this.lowStockDoses = 3,
    this.appSyncMinutes = 10,
  });

  /// Minutes between medicine rings; Later waits this long too.
  final int repeatMinutes;
  /// Rings per dose time.
  final int rings;
  /// How long one ring sounds.
  final int ringMinutes;
  /// "Taken" closes this long before the medicine's next dose.
  final int takenClosesBeforeNextMinutes;
  /// Days a test reminder rings.
  final int testReminderDays;
  /// Medicine box "running low" at this many doses left.
  final int lowStockDoses;
  /// How often the app asks the server again while open.
  final int appSyncMinutes;

  /// The values in use (process-wide).
  static ReminderTiming current = const ReminderTiming();

  static const _key = 'reminder_timing';

  static int _int(Object? v, int fallback, int min, int max) =>
      v is int && v >= min && v <= max ? v : fallback;

  factory ReminderTiming.fromJson(Map<String, dynamic> json) {
    const d = ReminderTiming();
    return ReminderTiming(
      repeatMinutes: _int(json['repeatMinutes'], d.repeatMinutes, 1, 180),
      rings: _int(json['rings'], d.rings, 1, 10),
      ringMinutes: _int(json['ringMinutes'], d.ringMinutes, 1, 10),
      takenClosesBeforeNextMinutes: _int(json['takenClosesBeforeNextMinutes'], d.takenClosesBeforeNextMinutes, 0, 720),
      testReminderDays: _int(json['testReminderDays'], d.testReminderDays, 1, 14),
      lowStockDoses: _int(json['lowStockDoses'], d.lowStockDoses, 0, 100),
      appSyncMinutes: _int(json['appSyncMinutes'], d.appSyncMinutes, 1, 1440),
    );
  }

  Map<String, dynamic> toJson() => {
        'repeatMinutes': repeatMinutes,
        'rings': rings,
        'ringMinutes': ringMinutes,
        'takenClosesBeforeNextMinutes': takenClosesBeforeNextMinutes,
        'testReminderDays': testReminderDays,
        'lowStockDoses': lowStockDoses,
        'appSyncMinutes': appSyncMinutes,
      };

  /// At start (app and background isolates): the last values the server sent.
  static Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) current = ReminderTiming.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {/* defaults */}
  }

  /// The server's answer; true when something changed (reminders must be rescheduled).
  static Future<bool> apply(Map<String, dynamic> json) async {
    final next = ReminderTiming.fromJson(json);
    final changed = jsonEncode(next.toJson()) != jsonEncode(current.toJson());
    current = next;
    if (changed) {
      try {
        await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(next.toJson()));
      } catch (_) {}
    }
    return changed;
  }
}
