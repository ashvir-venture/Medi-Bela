import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/medicine_schedule/presentation/medicines_tab_screen.dart';

/// A small phone (320 dp wide) with the system font enlarged.
Future<void> _pump(WidgetTester tester, AppStrings strings) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MedicinesSegmentBar(
              strings: strings,
              selected: MedicinesSegment.prescriptions,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

double _lineHeight(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).size.height;

void main() {
  for (final strings in [enStrings, bnStrings]) {
    testWidgets('labels stay on one line on a small phone (${strings.today})', (tester) async {
      await _pump(tester, strings);
      final oneLine = _lineHeight(tester, strings.today);
      // A broken word ("Prescriptio / ns") would make the paragraph two lines tall.
      expect(_lineHeight(tester, strings.prescriptionsButton), oneLine);
      expect(_lineHeight(tester, strings.myMedicines), oneLine);
      expect(tester.takeException(), isNull); // no overflow
    });
  }
}
