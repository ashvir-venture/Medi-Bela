/// What this phone currently allows for on-device medicine reminders.
class ReminderStatus {
  const ReminderStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.batteryUnrestricted,
    this.overlayAllowed = true,
    this.fullScreenAllowed = true,
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

  /// "Display over other apps": reminders open as a full screen over
  /// whatever is on screen (Round 13). Without it, the ringing banner.
  final bool overlayAllowed;

  /// Android 14+ "full-screen notifications": the reminder opens over the
  /// lock screen.
  final bool fullScreenAllowed;

  /// Both full-screen permissions given.
  bool get fullScreenReady => overlayAllowed && fullScreenAllowed;

  /// Reminders won't show at all.
  bool get blocked => !notificationsAllowed;

  /// Reminders show, but may be late.
  bool get mayBeLate => notificationsAllowed && !exactAlarmsAllowed;
}
