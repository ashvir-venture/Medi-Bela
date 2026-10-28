import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_config.dart';

/// Whether medicine reminders are on, readable synchronously by
/// [NotificationScheduler]. The account (server) owns the setting; this is
/// its local mirror, updated by SessionServices whenever the profile loads
/// or changes, and loaded from SharedPreferences at startup (also in
/// background isolates), so reminders obey it offline too.
class ReminderPreference {
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(PrefsKeys.medicineRemindersEnabled) ?? true;
  }

  /// Returns true when the value changed.
  Future<bool> set(bool enabled) async {
    final changed = enabled != _enabled;
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.medicineRemindersEnabled, enabled);
    return changed;
  }
}
