class HealthReminderModel {
  const HealthReminderModel({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledAt,
    required this.status,
    this.completedAt,
    this.syncState = 'synced',
  });

  final String id;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final String status; // PENDING | COMPLETED | DISMISSED
  final DateTime? completedAt;
  /// synced | pending | syncing | failed — see [CachedHealthReminders.syncState].
  final String syncState;

  bool get isCompleted => status == 'COMPLETED';
  bool get isDue => status == 'PENDING' && !scheduledAt.isAfter(DateTime.now());
  bool get isUpcoming => status == 'PENDING' && scheduledAt.isAfter(DateTime.now());

  factory HealthReminderModel.fromJson(Map<String, dynamic> json) {
    return HealthReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      status: json['status'] as String,
      completedAt:
          json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
    );
  }
}

/// Matches the backend's `HealthRecordType` enum exactly.
class HealthRecordType {
  HealthRecordType._();

  static const String bloodPressure = 'BLOOD_PRESSURE';
  static const String bloodSugar = 'BLOOD_SUGAR';
  static const String weight = 'WEIGHT';
  static const String temperature = 'TEMPERATURE';
  static const String heartRate = 'HEART_RATE';
  static const String other = 'OTHER';

  static const all = [bloodPressure, bloodSugar, weight, temperature, heartRate, other];

  static String displayName(String type) {
    return switch (type) {
      bloodPressure => 'Blood pressure',
      bloodSugar => 'Blood sugar',
      weight => 'Weight',
      temperature => 'Temperature',
      heartRate => 'Heart rate',
      _ => 'Other',
    };
  }
}

class HealthRecordModel {
  const HealthRecordModel({
    required this.id,
    required this.type,
    required this.value,
    this.unit,
    this.notes,
    required this.recordedAt,
    required this.syncState,
  });

  final String id;
  final String type;
  final String value;
  final String? unit;
  final String? notes;
  final DateTime recordedAt;
  /// draft | queued | syncing | synced | failed — mirrors
  /// `PrescriptionDraftModel.status` naming for consistency.
  final String syncState;

  factory HealthRecordModel.fromJson(Map<String, dynamic> json) {
    return HealthRecordModel(
      id: json['id'] as String,
      type: json['type'] as String,
      value: json['value'] as String,
      unit: json['unit'] as String?,
      notes: json['notes'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      syncState: 'synced',
    );
  }
}

/// One item within a published [HealthSuggestionModel] — an open-ended
/// (category, text) pair, e.g. category "Food to avoid", text "Avoid
/// grapefruit juice while on this medicine". `category` is free text
/// chosen by the AI/admin, not a fixed enum — mirrors the backend's
/// `SuggestionItem` shape exactly (see `ai-suggestion.service.ts`).
class HealthSuggestionItem {
  const HealthSuggestionItem({required this.category, required this.text});

  final String category;
  final String text;

  factory HealthSuggestionItem.fromJson(Map<String, dynamic> json) {
    return HealthSuggestionItem(
      category: json['category'] as String,
      text: json['text'] as String,
    );
  }
}

/// An AI-generated, pharmacist-reviewed set of health suggestions for
/// the current user, based on their verified medicines. Only ever
/// fetched from `/health-suggestions/mine`, which the backend guarantees
/// returns PUBLISHED rows only — there is no DRAFT state reachable from
/// the mobile app.
class HealthSuggestionModel {
  const HealthSuggestionModel({
    required this.id,
    required this.itemsEn,
    required this.itemsBn,
    required this.publishedAt,
  });

  final String id;
  final List<HealthSuggestionItem> itemsEn;
  final List<HealthSuggestionItem> itemsBn;
  final DateTime? publishedAt;

  /// Picks the item list matching [languageCode] ('en' | 'bn'), falling
  /// back to English for any other/unsupported code.
  List<HealthSuggestionItem> itemsFor(String languageCode) {
    return languageCode == 'bn' ? itemsBn : itemsEn;
  }

  factory HealthSuggestionModel.fromJson(Map<String, dynamic> json) {
    return HealthSuggestionModel(
      id: json['id'] as String,
      itemsEn: (json['itemsEn'] as List<dynamic>)
          .map((e) => HealthSuggestionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      itemsBn: (json['itemsBn'] as List<dynamic>)
          .map((e) => HealthSuggestionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      publishedAt:
          json['publishedAt'] == null ? null : DateTime.parse(json['publishedAt'] as String),
    );
  }
}
