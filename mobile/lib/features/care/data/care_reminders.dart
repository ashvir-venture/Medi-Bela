import '../../../core/localization/app_strings.dart';
import '../../../notifications/notification_scheduler.dart';
import '../domain/care_models.dart';
import 'care_repository.dart';

/// Visit, check-up and chemo reminders the day before at 19:00; own tests
/// the day before at 09:00 (owner, 2026-11-11).
const visitReminderHour = 19;
const testReminderHour = 9;

/// How far ahead dialysis sessions are planned.
const _dialysisDays = 14;

String _hhmm(String hhmm, bool bn) {
  final parts = hhmm.split(':').map(int.parse).toList();
  final h = parts[0] % 12 == 0 ? 12 : parts[0] % 12;
  final ampm = parts[0] < 12 ? (bn ? 'সকাল' : 'AM') : (bn ? 'বিকাল' : 'PM');
  final text = '$h:${parts[1].toString().padLeft(2, '0')}';
  return bn ? '$ampm ${const Round15Strings(true).n(text)}' : '$text $ampm';
}

/// Every care reminder still ahead of [now], from the cached care and
/// records. Pure, so it can be tested; the scheduler keeps the next few.
List<CareReminderItem> planCareReminders(CareOverview care, RecordsOverview records, Round15Strings s, DateTime now) {
  final items = <CareReminderItem>[];
  final today = dateOnly(now);

  for (final a in records.appointments) {
    if (!a.remind || a.done || a.day.isBefore(today)) continue;
    final day = a.day.subtract(const Duration(days: 1));
    final at = DateTime(day.year, day.month, day.day, visitReminderHour);
    items.add(CareReminderItem(
      key: 'appt:${a.id}',
      at: at,
      title: switch (a.kind) {
        AppointmentKind.anc => s.remCheckupTitle,
        AppointmentKind.chemo => s.remSessionTitle,
        AppointmentKind.visit => s.remVisitTitle,
      },
      body: s.remVisitBody(a.time == null ? null : _hhmm(a.time!, s.bn)),
      route: a.conditionCode == null ? '/health/records' : '/health/care/${a.conditionCode}',
    ));
  }

  for (final t in records.upcomingTests) {
    if (!t.remind || t.day.isBefore(today)) continue;
    final day = t.day.subtract(const Duration(days: 1));
    items.add(CareReminderItem(
      key: 'test:${t.id}',
      at: DateTime(day.year, day.month, day.day, testReminderHour),
      title: s.remTestTitle,
      body: s.remTestBody(t.fasting),
      route: '/health/records',
    ));
  }

  final kidney = care.setting('kidney');
  final time = kidney['dialysisTime'] as String?;
  final days = [for (final d in (kidney['dialysisDays'] as List? ?? [])) (d as num).toInt()];
  if (care.has('kidney') && kidney['dialysis'] == true && time != null && days.isNotEmpty) {
    final parts = time.split(':').map(int.parse).toList();
    for (var i = 0; i < _dialysisDays; i++) {
      final day = today.add(Duration(days: i));
      // DateTime.weekday: Mon=1..Sun=7; the app stores Sun=0..Sat=6.
      if (!days.contains(day.weekday % 7)) continue;
      final session = DateTime(day.year, day.month, day.day, parts[0], parts[1]);
      items.add(CareReminderItem(
        key: 'dialysis:${isoDate(day)}',
        at: session.subtract(const Duration(hours: 1)),
        title: s.remDialysisTitle(_hhmm(time, s.bn)),
        body: s.remDialysisBody,
        route: '/health/care/kidney',
      ));
    }
  }

  final pen = care.setting('diabetes')['pen'];
  if (care.has('diabetes') && pen is Map && pen['openedOn'] is String) {
    final opened = parseDate(pen['openedOn'] as String);
    final useBy = opened.add(Duration(days: (pen['lifeDays'] as num).toInt()));
    final remindDay = useBy.subtract(Duration(days: (pen['remindDaysBefore'] as num?)?.toInt() ?? 0));
    items.add(CareReminderItem(
      key: 'pen:${pen['openedOn']}',
      at: DateTime(remindDay.year, remindDay.month, remindDay.day, testReminderHour),
      title: s.remPenTitle,
      body: s.remPenBody,
      route: '/health/insulin',
    ));
  }

  return items.where((i) => i.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
}

/// Puts the planned care reminders on the OS (offline, from the cache).
class CareReminders {
  CareReminders({required CareRepository repository, required NotificationScheduler scheduler, AppStrings Function()? strings})
      : _repo = repository,
        _scheduler = scheduler,
        _strings = strings ?? (() => bnStrings);

  final CareRepository _repo;
  final NotificationScheduler _scheduler;
  final AppStrings Function() _strings;

  Future<void> reconcile() async {
    try {
      final items = planCareReminders(await _repo.care(), await _repo.records(), _strings().r15, DateTime.now());
      await _scheduler.reconcileCareReminders(items);
    } catch (_) {
      // Reminders are a help; a bad cache entry never breaks the refresh.
    }
  }
}
