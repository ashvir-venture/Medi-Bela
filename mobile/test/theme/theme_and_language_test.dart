import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/constants/app_config.dart';
import 'package:mobile/core/localization/locale_controller.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/theme_mode_controller.dart';
import 'package:mobile/widgets/language_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('theme mode', () {
    test('unknown or missing values follow the phone', () {
      expect(parseThemeMode(null), ThemeMode.system);
      expect(parseThemeMode('purple'), ThemeMode.system);
      expect(parseThemeMode('dark'), ThemeMode.dark);
    });

    test('the choice is saved and restored on this device', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ThemeModeController();
      await first.setMode(ThemeMode.dark);
      expect((await SharedPreferences.getInstance()).getString(PrefsKeys.themeMode), 'dark');

      final restored = ThemeModeController();
      await Future<void>.delayed(Duration.zero);
      expect(restored.state, ThemeMode.dark);
    });

    test('light mode keeps the colors used before dark mode', () {
      final light = AppTheme.light();
      expect(light.extension<AppPalette>()!.muted, Colors.grey.shade700);
      expect(light.extension<AppPalette>()!.success, Colors.green.shade700);
      expect(light.scaffoldBackgroundColor, AppTheme.background);
      expect(light.cardTheme.color, Colors.white);
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(AppTheme.dark().extension<AppPalette>(), AppPalette.dark);
    });
  });

  testWidgets('the sign-in language switcher toggles and remembers an unsynced choice', (tester) async {
    SharedPreferences.setMockInitialValues({PrefsKeys.languageCode: 'en'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: LanguageSwitcher())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('বাংলা'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('language-switcher')));
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider).languageCode, 'bn');
    expect(find.text('English'), findsOneWidget);
    // Uploaded to the account after sign-in, like a choice made in Profile.
    expect(await container.read(localeControllerProvider.notifier).hasUnsyncedChoice(), isTrue);
  });
}
