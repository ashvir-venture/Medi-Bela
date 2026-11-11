import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/reading_rules.dart';

/// Small building blocks of the Round 15-16 screens, in the demo's look
/// (rounded tiles, pill chips, cards with a bold heading). Colours only from
/// [AppPalette].

/// Outlined buttons are full width in the theme; inside a Row they need this.
final compactOutlined = OutlinedButton.styleFrom(minimumSize: const Size(64, 44), padding: const EdgeInsets.symmetric(horizontal: 14));

enum ToneKind { primary, navy, ok, warn, violet, error, neutral }

(Color, Color) toneColors(BuildContext context, ToneKind tone) {
  final p = context.palette;
  return switch (tone) {
    ToneKind.primary => (p.primaryContainer, p.onPrimaryContainer),
    ToneKind.navy => (p.navyContainer, p.onNavyContainer),
    ToneKind.ok => (p.okContainer, p.onOkContainer),
    ToneKind.warn => (p.warnContainer, p.onWarnContainer),
    ToneKind.violet => (p.violetContainer, p.onVioletContainer),
    ToneKind.error => (p.errorContainer, p.onErrorContainer),
    ToneKind.neutral => (p.surface2, p.muted2),
  };
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = ToneKind.primary, this.size = 44});

  final IconData icon;
  final ToneKind tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size >= 44 ? 12 : 10)),
      child: Icon(icon, color: fg, size: size * 0.55),
    );
  }
}

class StateChip extends StatelessWidget {
  const StateChip(this.text, {super.key, this.tone = ToneKind.ok, this.icon});

  final String text;
  final ToneKind tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }
}

/// The chip for a range state (null = no chip).
Widget? rangeChip(RangeState? state, {required String inRange, required String above, required String below}) =>
    switch (state) {
      RangeState.inRange => StateChip(inRange, tone: ToneKind.ok, icon: Icons.check),
      RangeState.above => StateChip(above, tone: ToneKind.warn, icon: Icons.error_outline),
      RangeState.below => StateChip(below, tone: ToneKind.warn, icon: Icons.error_outline),
      null => null,
    };

/// A card with a bold heading row (title, optional trailing action).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, this.subtitle, required this.children, this.color, this.outlineError = false});

  final String? title;
  final Widget? trailing;
  final String? subtitle;
  final List<Widget> children;
  final Color? color;
  final bool outlineError;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Card(
      color: color,
      shape: outlineError
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.later, width: 1.5))
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Row(children: [
                Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ?trailing,
              ]),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(color: p.muted, fontSize: 13)),
            ],
            if (title != null || subtitle != null) const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A selectable pill (choice chips in the demo).
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.urgent = false, this.square = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool urgent;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final on = selected ? (urgent ? p.later : Theme.of(context).colorScheme.primary) : p.surface;
    final fg = selected ? (urgent ? p.onLater : Theme.of(context).colorScheme.onPrimary) : p.head;
    final border = selected ? on : (urgent ? p.later.withValues(alpha: 0.5) : p.line2);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(square ? 12 : 999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: on,
            borderRadius: BorderRadius.circular(square ? 12 : 999),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
            Flexible(
              child: Text(label,
                  style: TextStyle(color: fg, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A small value box ("Morning avg 132/84, 7 days").
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.muted, fontSize: 13)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.head)),
        if (sub != null) Text(sub!, style: TextStyle(color: p.muted, fontSize: 13)),
      ]),
    );
  }
}

/// Three or two equal boxes in a row.
class StatRow extends StatelessWidget {
  const StatRow(this.boxes, {super.key});

  final List<Widget> boxes;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < boxes.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: boxes[i]),
          ],
        ],
      );
}

/// Seven dots, oldest first: green done, orange not done, grey unknown;
/// the last (today) ringed.
class SevenDots extends StatelessWidget {
  const SevenDots(this.values, {super.key});

  final List<int?> values;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < values.length; i++)
        Container(
          margin: const EdgeInsets.only(left: 3),
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: values[i] == 1 ? p.taken : values[i] == 0 ? p.warningStrong.withValues(alpha: 0.6) : p.track,
            border: i == values.length - 1 ? Border.all(color: p.line2, width: 1.5) : null,
          ),
        ),
    ]);
  }
}

/// A line chart of up to 14 values (nulls skipped) with an optional
/// in-range band; points outside the band are orange.
class SparkChart extends StatelessWidget {
  const SparkChart({super.key, required this.values, this.low, this.high, this.labels = const [], this.height = 150, this.second});

  final List<double?> values;
  final List<double?>? second;
  final double? low;
  final double? high;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(children: [
      SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparkPainter(
            values: values,
            second: second,
            low: low,
            high: high,
            line: p.head,
            line2: Theme.of(context).colorScheme.primary,
            band: p.okContainer,
            out: p.warningStrong,
            grid: p.line3,
          ),
        ),
      ),
      if (labels.isNotEmpty)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final l in labels) Text(l, style: TextStyle(color: p.muted, fontSize: 12))],
        ),
    ]);
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, this.second, this.low, this.high, required this.line, required this.line2, required this.band, required this.out, required this.grid});

  final List<double?> values;
  final List<double?>? second;
  final double? low;
  final double? high;
  final Color line;
  final Color line2;
  final Color band;
  final Color out;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...values, ...?second].whereType<double>().toList();
    if (all.isEmpty) return;
    var lo = [...all, ?low].reduce((a, b) => a < b ? a : b);
    var hi = [...all, ?high].reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;
    const top = 6.0, bottom = 6.0;
    double y(double v) => top + (hi - v) / (hi - lo) * (size.height - top - bottom);
    double x(int i, int n) => n <= 1 ? size.width / 2 : 8 + i * (size.width - 16) / (n - 1);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final gy = top + k * (size.height - top - bottom) / 3;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }
    if (low != null || high != null) {
      final bandTop = y(high ?? hi);
      final bandBottom = y(low ?? lo);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(0, bandTop, size.width, bandBottom), const Radius.circular(6)),
        Paint()..color = band.withValues(alpha: 0.8),
      );
    }
    void series(List<double?> vs, Color c) {
      final path = Path();
      var started = false;
      for (var i = 0; i < vs.length; i++) {
        final v = vs[i];
        if (v == null) continue;
        final o = Offset(x(i, vs.length), y(v));
        if (!started) {
          path.moveTo(o.dx, o.dy);
          started = true;
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < vs.length; i++) {
        final v = vs[i];
        if (v == null) continue;
        final outside = (high != null && v > high!) || (low != null && v < low!);
        canvas.drawCircle(Offset(x(i, vs.length), y(v)), outside ? 5 : 3.5, Paint()..color = outside ? out : c);
      }
    }

    series(values, line);
    if (second != null) series(second!, line2);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.second != second || old.low != low || old.high != high;
}

/// Lab results as bars with the value above and the date below (last 6).
class TrendBars extends StatelessWidget {
  const TrendBars({super.key, required this.points, required this.empty, this.unit});

  /// (label under, value)
  final List<(String, double)> points;
  final String empty;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (points.isEmpty) return Text(empty, style: TextStyle(color: p.muted));
    final shown = points.length > 6 ? points.sublist(points.length - 6) : points;
    final mx = shown.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 110,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final pt in shown)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(_num(pt.$2), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: 22,
                  height: mx <= 0 ? 8 : (pt.$2 / mx * 60).clamp(8, 60).toDouble(),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(pt.$1, style: TextStyle(color: p.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
        ]),
      ),
      if (unit != null) Text(unit!, style: TextStyle(color: p.muted, fontSize: 12)),
    ]);
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(v < 10 ? 2 : 1);
}

/// A note with an icon (info / shield lines in the demo).
class NoteLine extends StatelessWidget {
  const NoteLine(this.text, {super.key, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: p.muted)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: p.muted, fontSize: 13))),
    ]);
  }
}

/// A date box: big day number over the short month.
class DateBox extends StatelessWidget {
  const DateBox({super.key, required this.day, required this.month});

  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: p.navyContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.onNavyContainer)),
        Text(month, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.onNavyContainer)),
      ]),
    );
  }
}
