import '../../prescription/domain/prescription_models.dart' show parseScheduleTimes;

/// A reminder the user (or their caregiver) set up (Round 13): "Time for
/// your {name}" with [description], at [scheduleTimes] every day or every
/// [intervalDays] days from [startDate], until [endDate] (none = until removed).
class PersonalReminderModel {
  const PersonalReminderModel({
    required this.id,
    required this.name,
    this.description,
    required this.scheduleTimes,
    this.intervalDays = 1,
    required this.startDate,
    this.endDate,
    this.byCaregiver = false,
  });

  final String id;
  final String name;
  final String? description;
  final List<String> scheduleTimes; // "HH:mm"
  final int intervalDays;
  final DateTime startDate;
  final DateTime? endDate;
  /// Set up by the family caregiver: Later on it tells them.
  final bool byCaregiver;

  factory PersonalReminderModel.fromJson(Map<String, dynamic> json) => PersonalReminderModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        scheduleTimes: parseScheduleTimes(json['scheduleTimes']),
        intervalDays: json['intervalDays'] as int? ?? 1,
        startDate: DateTime.parse(json['startDate'] as String).toLocal(),
        endDate: json['endDate'] == null ? null : DateTime.parse(json['endDate'] as String).toLocal(),
        byCaregiver: json['byCaregiver'] as bool? ?? false,
      );

  /// Ring times in [from, to): its times on every Nth day from the start day.
  List<DateTime> occurrences(DateTime from, DateTime to) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final last = endDate == null ? null : DateTime(endDate!.year, endDate!.month, endDate!.day);
    final result = <DateTime>[];
    for (var day = DateTime(from.year, from.month, from.day); day.isBefore(to); day = DateTime(day.year, day.month, day.day + 1)) {
      if (day.isBefore(start) || (last != null && day.isAfter(last))) continue;
      final offset = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
      if (offset % (intervalDays < 1 ? 1 : intervalDays) != 0) continue;
      for (final t in scheduleTimes) {
        final parts = t.split(':');
        if (parts.length != 2) continue;
        final at = DateTime(day.year, day.month, day.day, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
        if (!at.isBefore(from) && at.isBefore(to)) result.add(at);
      }
    }
    return result..sort();
  }
}
