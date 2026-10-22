/// Parses the medicine line items nested inside a prescription response.
class PrescriptionMedicineModel {
  const PrescriptionMedicineModel({
    required this.id,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions,
  });

  final String id;
  final String medicineName;
  final String dosage;
  final String frequency;
  final String duration;
  final String? instructions;

  factory PrescriptionMedicineModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionMedicineModel(
      id: json['id'] as String,
      medicineName: json['medicineName'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      duration: json['duration'] as String,
      instructions: json['instructions'] as String?,
    );
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
  });

  final String id;
  final String status; // PENDING | COMPLETED | REJECTED
  final String imageUrl;
  final String? rejectionReason;
  final DateTime createdAt;
  final List<PrescriptionMedicineModel> medicines;

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
    );
  }
}
