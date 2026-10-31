import '../../../notifications/reminder_timing.dart';
import '../../prescription/domain/prescription_models.dart' show parseScheduleTimes;

/// Who did something: the patient themself or their family caregiver.
enum ActedBy { you, caregiver }

ActedBy? parseActedBy(Object? raw) => switch (raw) {
      'YOU' => ActedBy.you,
      'CAREGIVER' => ActedBy.caregiver,
      _ => null,
    };

/// A routine as listed on "My medicines" (online), with its labels.
class ManagedRoutine {
  const ManagedRoutine({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.selfAdded,
    this.addedBy,
    this.editedBy,
    this.strength,
    this.doseAmount,
    this.scheduleTimes = const [],
    this.mealTimingId,
    this.mealTimingName,
    this.formId,
    this.formName,
    this.intervalDays = 1,
  });

  final String id;
  final String medicineName;
  final String dosage;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool selfAdded;
  final ActedBy? addedBy;
  final ActedBy? editedBy;
  final String? strength;
  final String? doseAmount;
  final List<String> scheduleTimes;
  final int? mealTimingId;
  final String? mealTimingName;
  final int? formId;
  final String? formName;
  /// Every N days (1 = every day).
  final int intervalDays;

  bool get continuous => endDate == null;

  /// Days in the course, counting the start day (null when continuous).
  int? get durationDays => endDate == null ? null : endDate!.difference(startDate).inDays + 1;

  factory ManagedRoutine.fromJson(Map<String, dynamic> json) {
    final meal = json['mealTiming'] as Map<String, dynamic>?;
    final form = json['form'] as Map<String, dynamic>?;
    return ManagedRoutine(
      id: json['id'] as String,
      medicineName: json['medicineName'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null ? null : DateTime.parse(json['endDate'] as String),
      selfAdded: json['selfAdded'] as bool? ?? false,
      addedBy: parseActedBy(json['addedBy']),
      editedBy: parseActedBy(json['editedBy']),
      strength: json['strength'] as String?,
      doseAmount: json['doseAmount'] as String?,
      scheduleTimes: parseScheduleTimes(json['scheduleTimes']),
      mealTimingId: json['mealTimingId'] as int?,
      mealTimingName: meal?['name'] as String?,
      formId: json['formId'] as int?,
      formName: form?['name'] as String?,
      intervalDays: json['intervalDays'] as int? ?? 1,
    );
  }
}

/// A medicine from the catalog, for the "Add a medicine" suggestions.
class CatalogMedicineOption {
  const CatalogMedicineOption({required this.id, required this.brandName, this.genericName, this.formName});

  final String id;
  final String brandName;
  final String? genericName;
  final String? formName;

  factory CatalogMedicineOption.fromJson(Map<String, dynamic> json) {
    final form = json['form'] as Map<String, dynamic>?;
    return CatalogMedicineOption(
      id: json['id'] as String,
      brandName: json['brandName'] as String,
      genericName: json['genericName'] as String?,
      formName: form?['name'] as String?,
    );
  }
}

class MedicineRoutineModel {
  const MedicineRoutineModel({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.active,
  });

  final String id;
  final String medicineName;
  final String dosage;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool active;

  factory MedicineRoutineModel.fromJson(Map<String, dynamic> json) {
    return MedicineRoutineModel(
      id: json['id'] as String,
      medicineName: json['medicineName'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null ? null : DateTime.parse(json['endDate'] as String),
      active: json['active'] as bool? ?? true,
    );
  }
}

class MedicineDoseModel {
  const MedicineDoseModel({
    required this.id,
    required this.routineId,
    required this.medicineName,
    required this.dosage,
    required this.scheduledAt,
    required this.status,
    this.takenAt,
    this.syncState = 'synced',
    this.takenUntil,
  });

  final String id;
  final String routineId;
  final String medicineName;
  final String dosage;
  final DateTime scheduledAt;
  final String status; // PENDING | TAKEN | MISSED | SKIPPED (server-authoritative meaning)
  final DateTime? takenAt;
  /// synced | pending | syncing | failed — sync state of the most recent
  /// local action on this dose (see [CachedMedicineDoses.syncState]).
  final String syncState;
  /// Last moment it can be marked taken: 1 hour before the same medicine's
  /// next dose (see [takenWindowEnd]). Null when not worked out.
  final DateTime? takenUntil;

  bool get isTaken => status == 'TAKEN';
  bool get isMissed => status == 'MISSED';
  bool get canMarkTaken => status != 'TAKEN' && status != 'SKIPPED';

  /// Owner, 2026-10-31: from the dose's own time (never an upcoming dose)
  /// until [takenUntil]. Two minutes of slack for the phone's clock.
  bool canMarkTakenAt(DateTime now) =>
      canMarkTaken &&
      !now.isBefore(scheduledAt.subtract(takenClockTolerance)) &&
      (takenUntil == null || !now.isAfter(takenUntil!));

  MedicineDoseModel withTakenUntil(DateTime? until) => MedicineDoseModel(
        id: id,
        routineId: routineId,
        medicineName: medicineName,
        dosage: dosage,
        scheduledAt: scheduledAt,
        status: status,
        takenAt: takenAt,
        syncState: syncState,
        takenUntil: until,
      );

  /// The mobile API nests the parent routine under `routine` (see
  /// `MedicineScheduleService.getTodaysSchedule` on the backend, which
  /// `include`s it) so the medicine name/dosage are available without a
  /// second request. The backend also returns a computed `displayStatus`
  /// (UPCOMING/DUE vs the stored status) but the client recomputes its
  /// own from [scheduledAt] so it stays live between syncs — see
  /// `computeDisplayStatus` in the presentation layer.
  factory MedicineDoseModel.fromJson(Map<String, dynamic> json) {
    final routine = json['routine'] as Map<String, dynamic>?;
    return MedicineDoseModel(
      id: json['id'] as String,
      routineId: json['routineId'] as String,
      medicineName: routine?['medicineName'] as String? ?? '',
      dosage: routine?['dosage'] as String? ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      status: json['status'] as String,
      takenAt: json['takenAt'] == null ? null : DateTime.parse(json['takenAt'] as String),
    );
  }
}

/// A tap this early still counts (the phone's clock may run fast).
const takenClockTolerance = Duration(minutes: 2);

/// A dose closes this long before the same medicine's next dose.
/// TAKEN_CLOSES_BEFORE_NEXT_MINUTES on the server (ReminderTiming), default 60.
Duration get takenClosesBeforeNext => Duration(minutes: ReminderTiming.current.takenClosesBeforeNextMinutes);

/// When [dose] stops accepting "taken": 1 hour before the next dose of the
/// same medicine among [known] (an 08:00 dose with 14:00 next closes at
/// 13:00). With no later dose known, a day after it, less that hour; the
/// server works the exact time out from the schedule and has the last word.
DateTime takenWindowEnd(MedicineDoseModel dose, Iterable<MedicineDoseModel> known) {
  DateTime? next;
  for (final d in known) {
    if (d.routineId != dose.routineId || !d.scheduledAt.isAfter(dose.scheduledAt)) continue;
    if (next == null || d.scheduledAt.isBefore(next)) next = d.scheduledAt;
  }
  return (next ?? dose.scheduledAt.add(const Duration(days: 1))).subtract(takenClosesBeforeNext);
}
