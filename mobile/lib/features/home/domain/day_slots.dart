import '../../../notifications/reminder_timing.dart';
import '../../medicine_schedule/domain/medicine_schedule_models.dart';

/// Round 14 (the demo's Home): today's doses in three times of day, each with
/// a state, and the one to act on next.
enum DaySlot { morning, noon, night }

/// Morning before 12:00, afternoon before 17:00, night after.
DaySlot slotOf(DateTime t) => t.hour < 12
    ? DaySlot.morning
    : t.hour < 17
        ? DaySlot.noon
        : DaySlot.night;

/// none: no dose; done: nothing left open (taken or missed); now: due within
/// one ring gap; late: due longer than that; later: still to come.
enum SlotState { none, done, now, late, later }

bool _closed(MedicineDoseModel d) => d.status == 'TAKEN' || d.status == 'MISSED' || d.status == 'SKIPPED';

class SlotView {
  const SlotView(this.slot, this.doses, this.state);

  final DaySlot slot;
  final List<MedicineDoseModel> doses;
  final SlotState state;

  List<MedicineDoseModel> get open => doses.where((d) => !_closed(d)).toList();
  int get missed => doses.where((d) => d.status == 'MISSED').length;

  /// The first open dose time (what a reminder group is keyed on).
  DateTime? get firstOpenAt {
    final o = open;
    if (o.isEmpty) return null;
    return o.map((d) => d.scheduledAt).reduce((a, b) => a.isBefore(b) ? a : b);
  }
}

SlotState slotState(List<MedicineDoseModel> doses, DateTime now, {Duration? ringGap}) {
  if (doses.isEmpty) return SlotState.none;
  final open = doses.where((d) => !_closed(d)).toList();
  if (open.isEmpty) return SlotState.done;
  final first = open.map((d) => d.scheduledAt).reduce((a, b) => a.isBefore(b) ? a : b);
  if (now.isBefore(first)) return SlotState.later;
  final gap = ringGap ?? Duration(minutes: ReminderTiming.current.repeatMinutes);
  return now.difference(first) <= gap ? SlotState.now : SlotState.late;
}

/// Morning, afternoon and night of [today]'s doses, in that order.
List<SlotView> daySlots(List<MedicineDoseModel> today, DateTime now, {Duration? ringGap}) => [
      for (final slot in DaySlot.values)
        () {
          final doses = today.where((d) => slotOf(d.scheduledAt) == slot).toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          return SlotView(slot, doses, slotState(doses, now, ringGap: ringGap));
        }(),
    ];

/// The time to show on Home: the first one with something still open, due
/// ones first. Null when everything today is done (or there is nothing).
SlotView? nextSlot(List<SlotView> slots) {
  for (final s in slots) {
    if (s.state == SlotState.now || s.state == SlotState.late) return s;
  }
  for (final s in slots) {
    if (s.state == SlotState.later) return s;
  }
  return null;
}

/// Which ring of a reminder group is current at [now] (0 = the first), for
/// Later from Home; never past the last one.
int currentStage(DateTime at, DateTime now) {
  final t = ReminderTiming.current;
  if (now.isBefore(at)) return 0;
  final n = now.difference(at).inMinutes ~/ t.repeatMinutes;
  return n >= t.rings - 1 ? t.rings - 1 : n;
}
