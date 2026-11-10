import 'package:flutter/material.dart';

/// Round 14: the look of the owner's demo ("Rafi's / Abba's Medi-Bela"):
/// teal primary, navy headings and Home band, soft blue-grey page, white
/// cards, pill buttons, green Taken and red Later. Big text and 48dp+ tap
/// targets stay (older users). The phone's own font is kept (owner,
/// 2026-11-10: no bundled font).
///
/// Light and dark share one builder; only colors differ. Screens take text
/// and status colors from [AppPalette] (`context.palette`) instead of fixed
/// shades, so both modes stay readable.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF0F7C8A); // demo --primary (teal)
  static const Color primaryDark = Color(0xFF075E69);
  static const Color danger = Color(0xFFB3261E);
  static const Color warning = Color(0xFFB85A10);
  static const Color background = Color(0xFFF3F6F9);
  static const Color darkBackground = Color(0xFF0B1626);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;
    final base = ColorScheme.fromSeed(seedColor: primary, brightness: brightness);
    final colorScheme = base.copyWith(
      primary: isDark ? const Color(0xFF5CC8D4) : primary,
      onPrimary: isDark ? const Color(0xFF00363D) : Colors.white,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.head,
      onSecondary: isDark ? const Color(0xFF0B1626) : Colors.white,
      secondaryContainer: p.navyContainer,
      onSecondaryContainer: p.onNavyContainer,
      tertiary: p.violet,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface2,
      surfaceContainerHigh: p.surface2,
      surfaceContainerHighest: p.segment,
      outline: p.line2,
      outlineVariant: p.line,
      error: p.later,
      onError: isDark ? const Color(0xFF4A1714) : Colors.white,
      errorContainer: p.errorContainer,
      onErrorContainer: p.onErrorContainer,
    );
    final scaffold = isDark ? darkBackground : background;
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.comfortable,
      extensions: [p],
      textTheme: TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.head),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.head),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.head),
        // Round 6: one step larger throughout for older eyes.
        titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        bodyLarge: const TextStyle(fontSize: 17, height: 1.45),
        bodyMedium: const TextStyle(fontSize: 16, height: 1.45),
        labelLarge: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.head),
        backgroundColor: p.surface,
        foregroundColor: p.head,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: p.line)),
      ),
      // Minimum 48dp touch targets throughout, per Material accessibility
      // guidance — important for users with reduced dexterity. Pill shapes
      // as in the demo.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: p.head,
          side: BorderSide(color: p.line2, width: 1.5),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: pill,
        ),
      ),
      // Filled buttons sit inside rows (e.g. "Mark as taken"), so they get a
      // tall minimum instead of full width.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: p.head),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: p.head,
        titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink),
        subtitleTextStyle: TextStyle(fontSize: 15, height: 1.4, color: p.muted),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.head),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        side: BorderSide(color: p.line2, width: 1.5),
        shape: pill,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: p.segment,
          selectedBackgroundColor: p.surface,
          selectedForegroundColor: p.onPrimaryContainer,
          foregroundColor: p.muted2,
          side: BorderSide(color: p.segment),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? colorScheme.primary : p.line2,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: p.link,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.line2, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.line2, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.later),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark ? BorderSide(color: p.line3) : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: p.line3, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: p.navBackground,
        indicatorColor: p.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? colorScheme.primary : p.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.line2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.head,
        foregroundColor: scaffold,
        shape: const CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(color: p.surface, fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Text and status colors that differ between light and dark mode, from the
/// demo's tokens (--ink, --muted, --head, --pc, --okc, --wc, --ec, --band ...).
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
    required this.ink,
    required this.muted2,
    required this.head,
    required this.link,
    required this.surface,
    required this.surface2,
    required this.segment,
    required this.line,
    required this.line2,
    required this.line3,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.navyContainer,
    required this.onNavyContainer,
    required this.taken,
    required this.onTaken,
    required this.okContainer,
    required this.onOkContainer,
    required this.later,
    required this.onLater,
    required this.warnContainer,
    required this.onWarnContainer,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.violet,
    required this.violetContainer,
    required this.onVioletContainer,
    required this.band,
    required this.band2,
    required this.bandLine,
    required this.bandMuted,
    required this.track,
    required this.navBackground,
  });

  /// Secondary text (--muted).
  final Color muted;

  /// Tertiary text and small icons.
  final Color subtle;

  /// Taken / active / complete (--okBright).
  final Color success;

  /// Due / pending / Late (--wbar).
  final Color warning;

  /// Warning text on a tinted box (--onWc).
  final Color warningStrong;

  /// Awaiting confirmation (--onNc).
  final Color info;

  /// Text on the amber hint box.
  final Color caution;

  /// Background of small tags.
  final Color tagBackground;

  final Color ink, muted2, head, link;
  final Color surface, surface2, segment, line, line2, line3;
  final Color primaryContainer, onPrimaryContainer, navyContainer, onNavyContainer;

  /// The Taken button (green) and its text.
  final Color taken, onTaken;
  final Color okContainer, onOkContainer;

  /// The Later button (red, owner 2026-11-10) and its text.
  final Color later, onLater;
  final Color warnContainer, onWarnContainer, errorContainer, onErrorContainer;
  final Color violet, violetContainer, onVioletContainer;

  /// Home's navy band (--band) and what sits on it.
  final Color band, band2, bandLine, bandMuted;
  final Color track, navBackground;

  static const light = AppPalette(
    muted: Color(0xFF4E5E6D),
    subtle: Color(0xFF5B6B7A),
    success: Color(0xFF2F7A3A),
    warning: Color(0xFFB85A10),
    warningStrong: Color(0xFF7A3A08),
    info: Color(0xFF143D6B),
    caution: Color(0xFF7A3A08),
    tagBackground: Color(0xFFFFFFFF),
    ink: Color(0xFF0F2137),
    muted2: Color(0xFF3E4E5C),
    head: Color(0xFF143D6B),
    link: Color(0xFF0F7C8A),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F6F9),
    segment: Color(0xFFE3EAEF),
    line: Color(0xFFD7E0E7),
    line2: Color(0xFFC9D4DD),
    line3: Color(0xFFEDF2F6),
    primaryContainer: Color(0xFFDDF1F3),
    onPrimaryContainer: Color(0xFF075E69),
    navyContainer: Color(0xFFE5EDF7),
    onNavyContainer: Color(0xFF143D6B),
    taken: Color(0xFF2F7A3A),
    onTaken: Color(0xFFFFFFFF),
    okContainer: Color(0xFFE3F2E1),
    onOkContainer: Color(0xFF2F7A3A),
    later: Color(0xFFB3261E),
    onLater: Color(0xFFFFFFFF),
    warnContainer: Color(0xFFFDEEDC),
    onWarnContainer: Color(0xFF7A3A08),
    errorContainer: Color(0xFFFCE8E6),
    onErrorContainer: Color(0xFF8C1D18),
    violet: Color(0xFF5B4B9A),
    violetContainer: Color(0xFFECE9F6),
    onVioletContainer: Color(0xFF4A3D80),
    band: Color(0xFF143D6B),
    band2: Color(0xFF1E4C80),
    bandLine: Color(0xFF3B6699),
    bandMuted: Color(0xFFC3D5EA),
    track: Color(0xFFDDE5EC),
    navBackground: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    muted: Color(0xFFA9B8C9),
    subtle: Color(0xFF93A3B5),
    success: Color(0xFF79C985),
    warning: Color(0xFFF2B266),
    warningStrong: Color(0xFFF6C98F),
    info: Color(0xFFBFD3EA),
    caution: Color(0xFFF6C98F),
    tagBackground: Color(0xFF1B2D47),
    ink: Color(0xFFE8EEF6),
    muted2: Color(0xFFC3CFDC),
    head: Color(0xFFE8EEF6),
    link: Color(0xFF7FD6DF),
    surface: Color(0xFF14243B),
    surface2: Color(0xFF1B2D47),
    segment: Color(0xFF1B2D47),
    line: Color(0xFF2A3E5A),
    line2: Color(0xFF3A5274),
    line3: Color(0xFF22364F),
    primaryContainer: Color(0xFF0E3E47),
    onPrimaryContainer: Color(0xFF7FD6DF),
    navyContainer: Color(0xFF1E3556),
    onNavyContainer: Color(0xFFBFD3EA),
    taken: Color(0xFF79C985),
    onTaken: Color(0xFF0B2A12),
    okContainer: Color(0xFF173A21),
    onOkContainer: Color(0xFFA6DDAE),
    later: Color(0xFFFFB4AB),
    onLater: Color(0xFF4A1714),
    warnContainer: Color(0xFF3A2610),
    onWarnContainer: Color(0xFFF6C98F),
    errorContainer: Color(0xFF4A1714),
    onErrorContainer: Color(0xFFFFDAD5),
    violet: Color(0xFFB9A8F0),
    violetContainer: Color(0xFF2A2350),
    onVioletContainer: Color(0xFFD9CFFF),
    band: Color(0xFF10294A),
    band2: Color(0xFF1B3A63),
    bandLine: Color(0xFF34567F),
    bandMuted: Color(0xFFA9B8C9),
    track: Color(0xFF2A3E5A),
    navBackground: Color(0xFF111F33),
  );

  List<Color> get _all => [
        muted, subtle, success, warning, warningStrong, info, caution, tagBackground, ink, muted2, head, link,
        surface, surface2, segment, line, line2, line3, primaryContainer, onPrimaryContainer, navyContainer,
        onNavyContainer, taken, onTaken, okContainer, onOkContainer, later, onLater, warnContainer,
        onWarnContainer, errorContainer, onErrorContainer, violet, violetContainer, onVioletContainer, band,
        band2, bandLine, bandMuted, track, navBackground,
      ];

  static AppPalette _fromList(List<Color> c) => AppPalette(
        muted: c[0], subtle: c[1], success: c[2], warning: c[3], warningStrong: c[4], info: c[5], caution: c[6],
        tagBackground: c[7], ink: c[8], muted2: c[9], head: c[10], link: c[11], surface: c[12], surface2: c[13],
        segment: c[14], line: c[15], line2: c[16], line3: c[17], primaryContainer: c[18],
        onPrimaryContainer: c[19], navyContainer: c[20], onNavyContainer: c[21], taken: c[22], onTaken: c[23],
        okContainer: c[24], onOkContainer: c[25], later: c[26], onLater: c[27], warnContainer: c[28],
        onWarnContainer: c[29], errorContainer: c[30], onErrorContainer: c[31], violet: c[32],
        violetContainer: c[33], onVioletContainer: c[34], band: c[35], band2: c[36], bandLine: c[37],
        bandMuted: c[38], track: c[39], navBackground: c[40],
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
    final c = _all;
    return _fromList([
      muted ?? c[0], subtle ?? c[1], success ?? c[2], warning ?? c[3], warningStrong ?? c[4], info ?? c[5],
      caution ?? c[6], tagBackground ?? c[7], ...c.sublist(8),
    ]);
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    final a = _all, b = other._all;
    return _fromList([for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!]);
  }
}

extension AppPaletteContext on BuildContext {
  /// Mode-aware text and status colors; falls back to the light set.
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
