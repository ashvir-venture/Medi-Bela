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

    // Round 14 (owner, 2026-11-10): the demo's colours. Teal primary, navy
    // headings, green Taken, red Later, in light and dark.
    test("the demo's colours, light and dark", () {
      final light = AppTheme.light();
      final p = light.extension<AppPalette>()!;
      expect(light.colorScheme.primary, const Color(0xFF0F7C8A));
      expect(p.head, const Color(0xFF143D6B));
      expect(p.ink, const Color(0xFF0F2137));
      expect(p.muted, const Color(0xFF4E5E6D));
      expect(p.taken, const Color(0xFF2F7A3A));
      expect(p.later, const Color(0xFFB3261E));
      expect(p.band, const Color(0xFF143D6B));
      expect(light.scaffoldBackgroundColor, AppTheme.background);
      expect(light.cardTheme.color, Colors.white);

      final dark = AppTheme.dark();
      expect(dark.brightness, Brightness.dark);
      expect(dark.extension<AppPalette>(), AppPalette.dark);
      expect(dark.colorScheme.primary, const Color(0xFF5CC8D4));
      expect(AppPalette.dark.later, const Color(0xFFFFB4AB));
      expect(dark.scaffoldBackgroundColor, AppTheme.darkBackground);
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
