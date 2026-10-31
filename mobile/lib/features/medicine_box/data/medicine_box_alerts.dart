import 'dart:convert';

import '../../../core/localization/app_strings.dart';
import '../../../notifications/full_screen_alarms.dart';
import '../../../notifications/local_notifications_gateway.dart';
import '../../../notifications/notification_ids.dart';
import '../../../notifications/push_service.dart' show alarmRouteForPayload;
import '../domain/medicine_box_models.dart';
import 'medicine_box_repository.dart';

/// Payload `type` of medicine box notifications (Round 13).
const medicineBoxType = 'MEDICINE_BOX';
const boxActionRefill = 'refill';
const boxActionIgnore = 'ignore';

String medicineBoxPayload(String routineId, StockAlert alert) =>
    jsonEncode({'type': medicineBoxType, 'routineId': routineId, 'kind': alert.name});

/// The tap payload for Refill: opens the refill form for that medicine.
String? boxRefillPayload(String? payload) {
  if (payload == null) return null;
  try {
    final map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    return jsonEncode({...map, 'kind': 'refill'});
  } catch (_) {
    return null;
  }
}

/// After doses are marked taken on this phone: "running low" (3 doses or
/// fewer left) as a normal notification, "ran out" as the ringing full screen
/// with Refill / Ignore (owner, 2026-10-31). Each at most once per count.
/// Lock-screen text never names the medicine.
class MedicineBoxAlerts {
  MedicineBoxAlerts({
    required MedicineBoxRepository repository,
    required LocalNotificationsGateway gateway,
    required AppStrings Function() strings,
    bool Function(String route)? openNow,
  })  : _repo = repository,
        _gateway = gateway,
        _strings = strings,
        _openNow = openNow;

  final MedicineBoxRepository _repo;
  final LocalNotificationsGateway _gateway;
  final AppStrings Function() _strings;
  /// Opens the "ran out" page right away when the app is in front (true).
  final bool Function(String route)? _openNow;

  Future<void> afterTaken(Iterable<String> routineIds) async {
    for (final routineId in routineIds.toSet()) {
      try {
        final (alert, item) = await _repo.nextAlert(routineId);
        if (alert == StockAlert.none || item == null) continue;
        await _show(alert, item);
      } catch (_) {
        // The box is a help, never a reason for "taken" to fail.
      }
    }
  }

  Future<void> _show(StockAlert alert, MedicineBoxItem item) async {
    final s = _strings();
    final payload = medicineBoxPayload(item.routineId, alert);
    final id = notificationIdForKey('box:${item.routineId}:${alert.name}');
    if (alert == StockAlert.low) {
      await _gateway.show(ScheduledReminder(
        id: id,
        title: s.boxLowTitle,
        body: s.boxLowBody,
        at: DateTime.now(),
        style: ReminderStyle.banner,
        payload: payload,
      ));
      return;
    }
    await _gateway.show(ScheduledReminder(
      id: id,
      title: s.boxEmptyTitle,
      body: s.boxEmptyBody,
      at: DateTime.now(),
      style: ReminderStyle.ringing,
      payload: payload,
      actions: [
        ReminderAction(boxActionIgnore, s.boxIgnoreAction),
        ReminderAction(boxActionRefill, s.boxRefillAction, opensApp: true),
      ],
    ));
    final route = alarmRouteForPayload(payload);
    if (route == null) return;
    if (_openNow?.call(route) ?? false) return;
    // App not in front: Android opens it over other apps when allowed.
    await FullScreenAlarms.add(id, DateTime.now().add(const Duration(seconds: 2)), route);
  }
}
