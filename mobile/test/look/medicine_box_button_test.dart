import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/medicine_box/presentation/medicine_box_screens.dart';

/// Owner's screenshot 2026-11-18: as the page's bottom bar, the box button
/// grew to the whole page (a bare Align takes all the height it is given),
/// which left the My medicine list empty and the button floating mid-page.
/// It must stay a short button at the bottom middle, clear of the AI button.
void main() {
  testWidgets('the box button stays a short bar at the bottom middle; the page keeps its body', (tester) async {
    SharedPreferences.setMockInitialValues({'pref_language_code': 'en'});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.read(stringsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox.expand(key: ValueKey('page-body')),
          bottomNavigationBar: MedicineBoxButton(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    const screen = Size(360, 800);
    final button = tester.getRect(find.byKey(const ValueKey('medicine-box-button')));
    final body = tester.getRect(find.byKey(const ValueKey('page-body')));

    // The body keeps nearly the whole page; the bar is short.
    expect(body.height, greaterThan(screen.height - 100));
    // At the bottom, horizontally centred.
    expect(button.bottom, greaterThan(screen.height - 80));
    expect((button.center.dx - screen.width / 2).abs(), lessThan(1));
    // Clear of the AI button's corner (56 wide + 16 margin on the right).
    expect(button.right, lessThan(screen.width - 72));
  });
}
