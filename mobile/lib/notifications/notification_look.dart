import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Round 18 (client note points 9, 13): how medicine reminders look on this
/// phone. Kept in SharedPreferences so the reminder isolate reads the same
/// values; loaded with [load] at start (main and the background isolate).
///
/// - [photoPath]: a small round photo the patient picked (a grandchild, the
///   family), shown on the reminder and its full page. Copied into the app's
///   own folder.
/// - [vibrate]: off = the alarm rings without vibrating (its own channel,
///   since Android fixes vibration per channel).
/// - [showNames]: off (default) = the lock screen says only "1 medicine at
///   8:00 PM"; on = the medicine names show there too (owner 2026-11-17:
///   only when the user turns it on).
class NotificationLook {
  const NotificationLook({this.photoPath, this.vibrate = true, this.showNames = false});

  final String? photoPath;
  final bool vibrate;
  final bool showNames;

  static const _photoKey = 'pref_notif_photo';
  static const _vibrateKey = 'pref_notif_vibrate';
  static const _namesKey = 'pref_notif_show_names';

  static NotificationLook current = const NotificationLook();

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final path = prefs.getString(_photoKey);
    current = NotificationLook(
      photoPath: path != null && File(path).existsSync() ? path : null,
      vibrate: prefs.getBool(_vibrateKey) ?? true,
      showNames: prefs.getBool(_namesKey) ?? false,
    );
  }

  static Future<void> setVibrate(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(_vibrateKey, on);
    current = NotificationLook(photoPath: current.photoPath, vibrate: on, showNames: current.showNames);
  }

  static Future<void> setShowNames(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(_namesKey, on);
    current = NotificationLook(photoPath: current.photoPath, vibrate: current.vibrate, showNames: on);
  }

  /// Keeps a copy of [picked] in the app's folder (null removes the photo).
  static Future<void> setPhoto(String? picked) async {
    final prefs = await SharedPreferences.getInstance();
    final old = current.photoPath;
    String? kept;
    if (picked != null) {
      final dir = await getApplicationSupportDirectory();
      kept = '${dir.path}/reminder_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked).copy(kept);
      await prefs.setString(_photoKey, kept);
    } else {
      await prefs.remove(_photoKey);
    }
    if (old != null && old != kept) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    current = NotificationLook(photoPath: kept, vibrate: current.vibrate, showNames: current.showNames);
  }
}
