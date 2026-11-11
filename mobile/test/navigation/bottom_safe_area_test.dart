import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/widgets/bottom_safe_area.dart';
import 'package:mobile/widgets/fit_label.dart';

void main() {
  testWidgets("nothing sits behind the phone's navigation bar", (tester) async {
    double? seenBottomPadding;
    late Size bodySize;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(400, 800), padding: EdgeInsets.only(bottom: 48)),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => BottomSafeArea(child: child!),
        home: Builder(builder: (context) {
          seenBottomPadding = MediaQuery.of(context).padding.bottom;
          return const Scaffold(body: SizedBox.expand(key: ValueKey('body')));
        }),
      ),
    ));
    bodySize = tester.getSize(find.byKey(const ValueKey('body')));
    expect(seenBottomPadding, 0); // screens no longer need to pad for it
    final screen = tester.getSize(find.byType(BottomSafeArea));
    expect(bodySize.height, screen.height - 48); // the page ends above the system buttons
  });

  testWidgets('a long label in a narrow button stays on one line', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Row(children: [
          Expanded(child: OutlinedButton(onPressed: () {}, child: const FitLabel(Text('লক্ষ্য ও সীমা বদলান আজই', key: ValueKey('l'))))),
          const SizedBox(width: 300),
        ]),
      ),
    ));
    expect(tester.getSize(find.byKey(const ValueKey('l'))).height, lessThan(40)); // one line, not wrapped
  });

  test('a test with its report: just "Have result" / "ফলাফল আছে"', () {
    expect(enStrings.r15.doneMode, 'Have result');
    expect(bnStrings.r15.doneMode, 'ফলাফল আছে');
    expect(enStrings.r15.doneAddResult, 'Have result');
    expect(bnStrings.r15.doneAddResult, 'ফলাফল আছে');
  });
}
