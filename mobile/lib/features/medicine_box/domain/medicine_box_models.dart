import '../../../notifications/reminder_timing.dart';

/// How many units one dose uses: the first number in the dose amount ("2
/// tablets" = 2, "1/2" or "½" = 0.5), else 1. Same rule as the server
/// (backend medicine-schedule/lib/dose-units.ts).
double unitsPerDoseOf(String? doseAmount) {
  if (doseAmount == null || doseAmount.trim().isEmpty) return 1;
  const bn = '০১২৩৪৫৬৭৮৯';
  var text = doseAmount.split('').map((c) {
    final i = bn.indexOf(c);
    return i >= 0 ? '$i' : c;
  }).join();
  text = text.replaceAll('½', '1/2').replaceAll('¼', '1/4');
  final fraction = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);
  if (fraction != null) {
    final bottom = double.parse(fraction.group(2)!);
    if (bottom > 0) return double.parse(fraction.group(1)!) / bottom;
  }
  final number = RegExp(r'\d+(\.\d+)?').firstMatch(text);
  final value = number == null ? null : double.tryParse(number.group(0)!);
  return value != null && value > 0 ? value : 1;
}

/// Round 18 (client point 6): one dose in the box's own unit. A syrup
/// counted in ml with a dose of "2 tsp" uses 10 ml (a teaspoon is 5 ml, a
/// tablespoon 15 ml). Same rule as the server (boxUnitsPerDose).
double boxUnitsPerDoseOf(String? doseAmount, String? boxUnit) {
  final n = unitsPerDoseOf(doseAmount);
  if (boxUnit != 'ml' || doseAmount == null) return n;
  final t = doseAmount.toLowerCase();
  if (RegExp('tbsp|tablespoon|টেবিল').hasMatch(t)) return n * 15;
  if (RegExp('tsp|teaspoon|spoon|চামচ').hasMatch(t)) return n * 5;
  return n;
}

/// "8", "2.5": no trailing ".0".
String formatUnits(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

/// One medicine in the box. [quantity] null = not counted yet.
class MedicineBoxItem {
  const MedicineBoxItem({
    required this.routineId,
    required this.medicineName,
    required this.dosage,
    this.doseAmount,
    this.formName,
    required this.unitsPerDose,
    this.quantity,
    this.countedAt,
    this.remaining,
    this.unit,
    this.perDay,
    this.refillDays = 3,
    this.daysLeft,
    this.asNeeded = false,
    this.pillColor,
    this.pillShape,
  });

  final String routineId;
  final String medicineName;
  final String dosage;
  final String? doseAmount;
  final String? formName;
  final double unitsPerDose;
  final double? quantity;
  final DateTime? countedAt;
  /// What the server counted as left (doses taken there since [countedAt]).
  final double? remaining;
  /// Round 18: what the count is in (tablet, ml, puff...).
  final String? unit;
  /// Round 18: units used a day on average (null for an as-needed medicine).
  final double? perDay;
  /// Round 18: remind when this many days are left.
  final int refillDays;
  /// Round 18: how long it lasts, from the server.
  final int? daysLeft;
  final bool asNeeded;
  final String? pillColor;
  final String? pillShape;

  bool get counted => quantity != null;

  /// Left after also taking off [pendingTaken] doses marked on this phone
  /// that the server hasn't seen yet.
  double? remainingWith(int pendingTaken) {
    final r = remaining;
    if (r == null) return null;
    final left = r - unitsPerDose * pendingTaken;
    return left < 0 ? 0 : left;
  }

  /// Whole doses left.
  int? dosesLeftWith(int pendingTaken) {
    final left = remainingWith(pendingTaken);
    return left == null ? null : (left / unitsPerDose + 1e-9).floor();
  }

  /// Round 18: whole days left (client: "20 ml a day from 200 ml = 10 days").
  int? daysLeftWith(int pendingTaken) {
    final left = remainingWith(pendingTaken);
    final day = perDay;
    if (left == null || day == null || day <= 0) return null;
    return (left / day + 1e-9).floor();
  }

  factory MedicineBoxItem.fromJson(Map<String, dynamic> json) => MedicineBoxItem(
        routineId: json['routineId'] as String,
        medicineName: json['medicineName'] as String,
        dosage: json['dosage'] as String? ?? '',
        doseAmount: json['doseAmount'] as String?,
        formName: json['formName'] as String?,
        unitsPerDose: (json['unitsPerDose'] as num?)?.toDouble() ?? unitsPerDoseOf(json['doseAmount'] as String?),
        quantity: (json['quantity'] as num?)?.toDouble(),
        countedAt: json['countedAt'] == null ? null : DateTime.parse(json['countedAt'] as String),
        remaining: (json['remaining'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        perDay: (json['perDay'] as num?)?.toDouble(),
        refillDays: json['refillDays'] as int? ?? 3,
        daysLeft: json['daysLeft'] as int?,
        asNeeded: json['asNeeded'] as bool? ?? false,
        pillColor: json['pillColor'] as String?,
        pillShape: json['pillShape'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'routineId': routineId,
        'medicineName': medicineName,
        'dosage': dosage,
        'doseAmount': doseAmount,
        'formName': formName,
        'unitsPerDose': unitsPerDose,
        'quantity': quantity,
        'countedAt': countedAt?.toUtc().toIso8601String(),
        'remaining': remaining,
        'unit': unit,
        'perDay': perDay,
        'refillDays': refillDays,
        'daysLeft': daysLeft,
        'asNeeded': asNeeded,
        'pillColor': pillColor,
        'pillShape': pillShape,
      };
}

/// Round 18 (client point 5): a box item with no reminder: a medicine kept
/// at home, or a care supply (insulin, test strips, needles, lancets...).
class BoxExtra {
  const BoxExtra({
    required this.id,
    required this.kind,
    required this.name,
    this.unit,
    this.perDay,
    this.refillDays = 5,
    required this.quantity,
    required this.countedAt,
    required this.remaining,
    this.daysLeft,
  });

  final String id;
  /// MEDICINE | SUPPLY
  final String kind;
  final String name;
  final String? unit;
  final double? perDay;
  final int refillDays;
  final double quantity;
  final DateTime countedAt;
  final double remaining;
  final int? daysLeft;

  bool get isSupply => kind == 'SUPPLY';
  bool get low => daysLeft != null && daysLeft! < refillDays;

  factory BoxExtra.fromJson(Map<String, dynamic> json) => BoxExtra(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? 'MEDICINE',
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String?,
        perDay: (json['perDay'] as num?)?.toDouble(),
        refillDays: json['refillDays'] as int? ?? 5,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        countedAt: DateTime.parse(json['countedAt'] as String),
        remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
        daysLeft: json['daysLeft'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'name': name,
        'unit': unit,
        'perDay': perDay,
        'refillDays': refillDays,
        'quantity': quantity,
        'countedAt': countedAt.toUtc().toIso8601String(),
        'remaining': remaining,
        'daysLeft': daysLeft,
      };
}

class MedicineBox {
  const MedicineBox({this.startedAt, this.items = const [], this.extras = const []});

  final DateTime? startedAt;
  final List<MedicineBoxItem> items;
  /// Round 18: medicines with no reminder and care supplies.
  final List<BoxExtra> extras;

  bool get started => startedAt != null;

  MedicineBoxItem? item(String routineId) {
    for (final i in items) {
      if (i.routineId == routineId) return i;
    }
    return null;
  }

  factory MedicineBox.fromJson(Map<String, dynamic> json) => MedicineBox(
        startedAt: json['startedAt'] == null ? null : DateTime.parse(json['startedAt'] as String),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((i) => MedicineBoxItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        extras: (json['extras'] as List<dynamic>? ?? const [])
            .map((i) => BoxExtra.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'items': [for (final i in items) i.toJson()],
        'extras': [for (final x in extras) x.toJson()],
      };
}

/// What the box should say after a dose: nothing, "running low" (3 doses
/// or fewer left), or "ran out" (less than one dose left).
enum StockAlert { none, low, empty }

/// Owner, 2026-10-31: notice at 3 doses left, full screen when it runs out.
StockAlert stockAlertFor(int? dosesLeft) {
  if (dosesLeft == null) return StockAlert.none;
  if (dosesLeft <= 0) return StockAlert.empty;
  if (dosesLeft <= ReminderTiming.current.lowStockDoses) return StockAlert.low;
  return StockAlert.none;
}
