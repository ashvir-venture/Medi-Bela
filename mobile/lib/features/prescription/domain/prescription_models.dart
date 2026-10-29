import 'dart:convert';

/// Parses the medicine line items nested inside a prescription response.
class PrescriptionMedicineModel {
  const PrescriptionMedicineModel({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
    this.strength,
    this.doseAmount,
    this.timesPerDay,
    this.scheduleTimes = const [],
    this.mealTimingId,
    this.durationDays,
    this.continuous = false,
    this.startDate,
  });

  final String id;
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;
  // Structured fields the pharmacist filled (used by Confirm or Edit).
  final String? strength;
  final String? doseAmount;
  final int? timesPerDay;
  final List<String> scheduleTimes; // "HH:mm"
  final int? mealTimingId;
  final int? durationDays;
  final bool continuous;
  final DateTime? startDate;

  factory PrescriptionMedicineModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionMedicineModel(
      id: json['id'] as String,
      medicineName: json['medicineName'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      duration: json['duration'] as String,
      instructions: json['instructions'] as String?,
      strength: json['strength'] as String?,
      doseAmount: json['doseAmount'] as String?,
      timesPerDay: json['timesPerDay'] as int?,
      scheduleTimes: parseScheduleTimes(json['scheduleTimes']),
      mealTimingId: json['mealTimingId'] as int?,
      durationDays: json['durationDays'] as int?,
      continuous: json['continuous'] as bool? ?? false,
      startDate: json['startDate'] == null ? null : DateTime.parse(json['startDate'] as String),
    );
  }
}

/// The server stores dose times as a JSON string (`["08:00","20:00"]`).
List<String> parseScheduleTimes(Object? raw) {
  if (raw is List) return raw.cast<String>();
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.cast<String>() : const [];
  } on FormatException {
    return const [];
  }
}

/// Row shape from `GET /prescriptions/mine`.
class PrescriptionSummaryModel {
  const PrescriptionSummaryModel({
    required this.id,
    required this.status,
    required this.imageUrl,
    this.rejectionReason,
    required this.createdAt,
    required this.medicines,
    this.uploadedByCaregiver = false,
    this.confirmedByCaregiver = false,
  });

  final String id;
  final String status; // PENDING | REJECTED | AWAITING_CONFIRMATION | ACTIVE | ENDED
  final String imageUrl;
  final String? rejectionReason;
  final DateTime createdAt;
  final List<PrescriptionMedicineModel> medicines;
  final bool uploadedByCaregiver;
  final bool confirmedByCaregiver;

  bool get awaitsConfirmation => status == 'AWAITING_CONFIRMATION';

  factory PrescriptionSummaryModel.fromJson(Map<String, dynamic> json) {
    final medicinesJson = json['medicines'] as List<dynamic>? ?? [];
    return PrescriptionSummaryModel(
      id: json['id'] as String,
      status: json['status'] as String,
      imageUrl: json['imageUrl'] as String,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      medicines: medicinesJson
          .map((m) => PrescriptionMedicineModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      uploadedByCaregiver: json['uploadedByCaregiver'] as bool? ?? false,
      confirmedByCaregiver: json['confirmedByCaregiver'] as bool? ?? false,
    );
  }
}

/// Full shape from `GET /prescriptions/:id` (adds reviewer info).
class PrescriptionDetailModel extends PrescriptionSummaryModel {
  const PrescriptionDetailModel({
    required super.id,
    required super.status,
    required super.imageUrl,
    super.rejectionReason,
    required super.createdAt,
    required super.medicines,
    super.uploadedByCaregiver,
    super.confirmedByCaregiver,
    this.reviewedByName,
  });

  final String? reviewedByName;

  factory PrescriptionDetailModel.fromJson(Map<String, dynamic> json) {
    final medicinesJson = json['medicines'] as List<dynamic>? ?? [];
    final reviewedBy = json['reviewedBy'] as Map<String, dynamic>?;
    return PrescriptionDetailModel(
      id: json['id'] as String,
      status: json['status'] as String,
      imageUrl: json['imageUrl'] as String,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      medicines: medicinesJson
          .map((m) => PrescriptionMedicineModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      reviewedByName: reviewedBy?['name'] as String?,
      uploadedByCaregiver: json['uploadedByCaregiver'] as bool? ?? false,
      confirmedByCaregiver: json['confirmedByCaregiver'] as bool? ?? false,
    );
  }
}
