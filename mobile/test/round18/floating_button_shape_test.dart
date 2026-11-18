import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_theme.dart';

/// Owner's screenshots 2026-11-17: labelled floating buttons ("Add a
/// medicine", "New conversation", "Add record") were squeezed into a circle
/// and cut their label, because the theme gave every floating button a
/// CircleBorder.
void main() {
  for (final entry in {'light': AppTheme.light(), 'dark': AppTheme.dark()}.entries) {
    testWidgets('a labelled floating button shows its whole label (${entry.key})', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: entry.value,
        home: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('New conversation'),
          ),
        ),
      ));

      final button = tester.getSize(find.byType(FloatingActionButton));
      final label = tester.getSize(find.text('New conversation'));
      expect(button.width, greaterThan(label.width + 24), reason: 'the label must fit inside the button');
      expect(button.width, greaterThan(button.height * 2));
      expect(entry.value.floatingActionButtonTheme.shape, isNot(isA<CircleBorder>()));
    });

    testWidgets('a plain floating button stays round (${entry.key})', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: entry.value,
        home: Scaffold(
          floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.smart_toy_outlined)),
        ),
      ));
      final size = tester.getSize(find.byType(FloatingActionButton));
      expect(size.width, size.height);
    });
  }
}
