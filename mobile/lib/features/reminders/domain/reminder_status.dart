/// What this phone currently allows for on-device medicine reminders.
class ReminderStatus {
  const ReminderStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.batteryUnrestricted,
  });

  /// Everything fine (or a platform without these settings, e.g. iOS).
  static const allOk = ReminderStatus(
    notificationsAllowed: true,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
  );

  /// App notifications on and the reminders channel not switched off.
  final bool notificationsAllowed;

  /// Android 12+ "Alarms & reminders". Without it reminders use inexact
  /// alarms and can arrive several minutes late.
  final bool exactAlarmsAllowed;

  /// Exempt from battery optimization. Advisory only: shown on the Reminder
  /// check screen, never in the banner.
  final bool batteryUnrestricted;

  /// Reminders won't show at all.
  bool get blocked => !notificationsAllowed;

  /// Reminders show, but may be late.
  bool get mayBeLate => notificationsAllowed && !exactAlarmsAllowed;
}
