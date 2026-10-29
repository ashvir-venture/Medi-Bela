import 'package:flutter/material.dart';

/// Deliberately plain and high-contrast. This app will be used by older
/// users managing medicine schedules, so we prioritize legibility and big
/// tap targets over visual flourish. See product brief: "Do not over-design
/// the MVP."
///
/// Light and dark share one builder; only colors differ. Screens take text
/// and status colors from [AppPalette] (`context.palette`) instead of fixed
/// shades, so both modes stay readable.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2E7D5B); // calm clinical green
  static const Color primaryDark = Color(0xFF1F5A40);
  static const Color danger = Color(0xFFB3261E);
  static const Color warning = Color(0xFFB8860B);
  static const Color background = Color(0xFFF7F8FA);
  static const Color darkBackground = Color(0xFF121614);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );
    final scaffold = isDark ? darkBackground : background;
    final strongText = isDark ? colorScheme.onSurface : Colors.black87;
    final border = isDark ? colorScheme.outlineVariant : Colors.grey.shade300;
    final surface = isDark ? colorScheme.surfaceContainer : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.comfortable,
      extensions: [isDark ? AppPalette.dark : AppPalette.light],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        // Round 6: one step larger throughout for older eyes.
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 17, height: 1.4),
        bodyMedium: TextStyle(fontSize: 16, height: 1.4),
        labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: strongText,
        ),
        backgroundColor: scaffold,
        foregroundColor: strongText,
      ),
      // Minimum 48dp touch targets throughout, per Material accessibility
      // guidance — important for users with reduced dexterity.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Filled buttons sit inside rows (e.g. "Mark as taken"), so they get a
      // tall minimum instead of full width.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: strongText),
        subtitleTextStyle: TextStyle(fontSize: 15, height: 1.35, color: strongText),
      ),
      chipTheme: const ChipThemeData(
        labelStyle: TextStyle(fontSize: 15),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? colorScheme.error : danger),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? colorScheme.outlineVariant : Colors.grey.shade200),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Text and status colors that differ between light and dark mode. The light
/// values are the shades the screens used before dark mode existed.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.muted,
    required this.subtle,
    required this.success,
    required this.warning,
    required this.warningStrong,
    required this.info,
    required this.caution,
    required this.tagBackground,
  });

  /// Secondary text (was grey.shade700).
  final Color muted;

  /// Tertiary text and small icons (was grey.shade600).
  final Color subtle;

  /// Taken / active / complete (was green.shade700).
  final Color success;

  /// Due / pending (was orange.shade800).
  final Color warning;

  /// Warning text on a tinted box (was orange.shade900).
  final Color warningStrong;

  /// Awaiting confirmation (was blue.shade700).
  final Color info;

  /// Text on the amber hint box (was amber.shade900).
  final Color caution;

  /// Background of small tags (was white).
  final Color tagBackground;

  static final light = AppPalette(
    muted: Colors.grey.shade700,
    subtle: Colors.grey.shade600,
    success: Colors.green.shade700,
    warning: Colors.orange.shade800,
    warningStrong: Colors.orange.shade900,
    info: Colors.blue.shade700,
    caution: Colors.amber.shade900,
    tagBackground: Colors.white,
  );

  static final dark = AppPalette(
    muted: Colors.grey.shade400,
    subtle: Colors.grey.shade500,
    success: Colors.green.shade300,
    warning: Colors.orange.shade300,
    warningStrong: Colors.orange.shade200,
    info: Colors.blue.shade300,
    caution: Colors.amber.shade200,
    tagBackground: Colors.grey.shade800,
  );

  @override
  AppPalette copyWith({
    Color? muted,
    Color? subtle,
    Color? success,
    Color? warning,
    Color? warningStrong,
    Color? info,
    Color? caution,
    Color? tagBackground,
  }) {
    return AppPalette(
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      warningStrong: warningStrong ?? this.warningStrong,
      info: info ?? this.info,
      caution: caution ?? this.caution,
      tagBackground: tagBackground ?? this.tagBackground,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningStrong: Color.lerp(warningStrong, other.warningStrong, t)!,
      info: Color.lerp(info, other.info, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      tagBackground: Color.lerp(tagBackground, other.tagBackground, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Mode-aware text and status colors; falls back to the light set.
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
