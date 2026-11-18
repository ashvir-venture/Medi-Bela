import 'package:flutter/material.dart';

/// Rows of [columns] equal tiles, each row as tall as its tallest tile (the
/// demo's 3-column grids), so long Bengali labels at Larger text are never
/// cut the way a fixed aspect ratio would cut them.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.columns = 3, this.gap = 10});

  final List<Widget> children;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < children.length; i += columns)
        Padding(
          padding: EdgeInsets.only(bottom: i + columns < children.length ? gap : 0),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = i; j < i + columns; j++) ...[
                if (j > i) SizedBox(width: gap),
                Expanded(child: j < children.length ? children[j] : const SizedBox.shrink()),
              ],
            ]),
          ),
        ),
    ]);
  }
}
