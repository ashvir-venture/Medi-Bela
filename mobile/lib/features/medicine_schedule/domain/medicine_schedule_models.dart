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

  bool get isTaken => status == 'TAKEN';
  bool get isMissed => status == 'MISSED';
  bool get canMarkTaken => status != 'TAKEN' && status != 'SKIPPED';

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
