import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/prescription/presentation/prescription_camera_screen.dart';

void main() {
  for (final lang in ['en', 'bn']) {
    final s = (lang == 'bn' ? bnStrings : enStrings).r18;

    testWidgets('[$lang] no camera: says so, the gallery still works, nothing to use yet; close returns nothing', (tester) async {
      SharedPreferences.setMockInitialValues({'pref_language_code': lang});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        container.read(stringsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      List<String>? result = const ['not closed'];
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
                      builder: (_) => PrescriptionCameraScreen(camerasLoader: () async => const []),
                    ));
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('camera-failed')), findsOneWidget);
      expect(find.text(s.cameraUnavailable), findsOneWidget);
      expect(find.text(s.fromGallery), findsOneWidget);
      expect(find.text(s.pagesN(0, 2)), findsOneWidget);
      // Use photos is off until there is one.
      final done = tester.widget<InkWell>(find.descendant(of: find.byKey(const ValueKey('camera-done')), matching: find.byType(InkWell)));
      expect(done.onTap, isNull);

      await tester.tap(find.byKey(const ValueKey('camera-close')));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  }
}
