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
      );
}

class MedicineBox {
  const MedicineBox({this.startedAt, this.items = const []});

  final DateTime? startedAt;
  final List<MedicineBoxItem> items;

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
      );
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
