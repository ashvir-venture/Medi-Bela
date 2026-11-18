import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Round 18 (client note point 1d): the medicine's real look. Colour codes
/// and shapes match the API (PILL_COLORS / PILL_SHAPES). Fixed colours are
/// the point here (a red tablet is red in dark mode too), so they live in
/// this one table, not in the theme palette.
const pillColorValues = <String, (Color fill, Color edge)>{
  'w': (Color(0xFFFFFFFF), Color(0xFF8C9BA8)),
  'y': (Color(0xFFF7DE7A), Color(0xFFB08F12)),
  'o': (Color(0xFFF5B27A), Color(0xFFB8611D)),
  'r': (Color(0xFFEF8A8A), Color(0xFFB23B3B)),
  'p': (Color(0xFFF2B5CF), Color(0xFFB0507A)),
  'b': (Color(0xFF9CC3EE), Color(0xFF4F7FB8)),
  'g': (Color(0xFF8FD19E), Color(0xFF3F8F52)),
  'n': (Color(0xFFC9A27E), Color(0xFF7A5534)),
  'k': (Color(0xFF4A4F57), Color(0xFF1E2228)),
  'c': (Color(0xFFEF8A8A), Color(0xFF4F7FB8)),
};

/// The picture of a medicine: its tablet / capsule when the user picked a
/// colour, otherwise the form's icon on a soft tile.
class PillIcon extends StatelessWidget {
  const PillIcon({super.key, this.color, this.shape, this.formName, this.size = 44});

  final String? color;
  final String? shape;
  final String? formName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color == null ? null : pillColorValues[color];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(size * 0.27)),
      alignment: Alignment.center,
      child: c == null
          ? Icon(formIcon(formName), size: size * 0.55, color: p.onPrimaryContainer)
          : CustomPaint(size: Size(size * 0.7, size * 0.5), painter: _PillPainter(c.$1, c.$2, shape ?? defaultShape(color!), twoTone: color == 'c')),
    );
  }

  static String defaultShape(String color) => color == 'c' ? 'capsule' : 'round';
}

/// An icon per medicine form (by the lookup name; English names in the DB).
IconData formIcon(String? formName) {
  final f = (formName ?? '').toLowerCase();
  if (f.contains('syrup') || f.contains('suspension') || f.contains('solution')) return Icons.local_drink_outlined;
  if (f.contains('capsule')) return Icons.medication_outlined;
  if (f.contains('insulin') || f.contains('injection')) return Icons.vaccines_outlined;
  if (f.contains('drop')) return Icons.water_drop_outlined;
  if (f.contains('inhaler')) return Icons.air_rounded;
  if (f.contains('cream') || f.contains('ointment') || f.contains('gel')) return Icons.spa_outlined;
  return Icons.medication_liquid_outlined;
}

class _PillPainter extends CustomPainter {
  _PillPainter(this.fill, this.edge, this.shape, {this.twoTone = false});

  final Color fill;
  final Color edge;
  final String shape;
  final bool twoTone;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final paint = Paint()..color = fill;
    final Path path;
    switch (shape) {
      case 'capsule':
        path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.2, w, h * 0.6), Radius.circular(h * 0.3)));
      case 'oval':
        path = Path()..addOval(Rect.fromLTWH(0, h * 0.1, w, h * 0.8));
      case 'oblong':
        path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.25, w, h * 0.5), Radius.circular(h * 0.12)));
      case 'square':
        final side = h;
        path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH((w - side) / 2, 0, side, side), Radius.circular(side * 0.2)));
      case 'half':
        final r = h;
        path = Path()
          ..moveTo((w - r) / 2, h)
          ..arcToPoint(Offset((w + r) / 2, h), radius: Radius.circular(r / 2))
          ..close();
      default:
        final d = h;
        path = Path()..addOval(Rect.fromLTWH((w - d) / 2, 0, d, d));
    }
    canvas.drawPath(path, paint);
    if (twoTone) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h), Paint()..color = const Color(0xFF9CC3EE));
      canvas.restore();
    }
    canvas.drawPath(path, stroke);
    if (shape == 'round' || shape == 'oval') {
      canvas.drawLine(Offset(w / 2, h * 0.25), Offset(w / 2, h * 0.75), stroke..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant _PillPainter old) => old.fill != fill || old.shape != shape || old.edge != edge;
}
