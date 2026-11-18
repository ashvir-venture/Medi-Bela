import 'package:flutter/material.dart';

/// Text that may wrap between words but never inside one (Round 18, owner's
/// screenshot: "Prescriptio / ns" under a Home service icon). When the
/// longest word is wider than the room, the font shrinks just enough for it
/// to fit (never below [minScale] of the size); text that fits is unchanged.
class WordSafeText extends StatelessWidget {
  const WordSafeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines = 2,
    this.minScale = 0.7,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int maxLines;
  final double minScale;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final scale = wordFitScale(text, base, constraints.maxWidth, scaler, minScale: minScale);
      final fontSize = base.fontSize ?? 14;
      return Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: base.copyWith(fontSize: fontSize * scale),
      );
    });
  }
}

/// The factor (minScale..1) that makes the widest word of [text] fit [maxWidth].
double wordFitScale(String text, TextStyle style, double maxWidth, TextScaler scaler, {double minScale = 0.7}) {
  if (!maxWidth.isFinite || maxWidth <= 0) return 1;
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  if (widest <= maxWidth) return 1;
  final scale = maxWidth / widest;
  return scale < minScale ? minScale : scale;
}
