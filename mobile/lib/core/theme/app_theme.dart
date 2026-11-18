import 'package:flutter/material.dart';

/// Round 14: the look of the owner's demo ("Rafi's / Abba's Medi-Bela"):
/// teal primary, navy headings and Home band, soft blue-grey page, white
/// cards, green Taken and red Later. 48dp+ tap targets stay (older users).
///
/// Round 18 (client note point 19, owner 2026-11-17): one bundled font for
/// both languages (Hind Siliguri, as the panel) and one type scale, so every
/// screen uses the same few sizes ([AppType]); help and comment text is
/// smaller, and lines sit closer together. The user's Text size (Normal /
/// Large / Larger) still scales all of it.
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
    // Buttons: a rounded rectangle (owner 2026-11-12: pills looked too round).
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.comfortable,
      extensions: [p],
      fontFamily: AppType.family,
      textTheme: AppType.textTheme(p),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontFamily: AppType.family, fontSize: AppType.appBar, height: AppType.tightHeight, fontWeight: FontWeight.w700, color: p.head),
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
          padding: buttonPadding,
          textStyle: const TextStyle(fontFamily: AppType.family, fontSize: AppType.button, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: p.head,
          side: BorderSide(color: p.line2, width: 1.5),
          padding: buttonPadding,
          textStyle: const TextStyle(fontFamily: AppType.family, fontSize: AppType.button, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      // Filled buttons sit inside rows (e.g. "Mark as taken"), so they get a
      // tall minimum instead of full width.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          textStyle: const TextStyle(fontFamily: AppType.family, fontSize: AppType.button, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: p.head),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: p.head,
        titleTextStyle: TextStyle(fontFamily: AppType.family, fontSize: AppType.title, height: AppType.tightHeight, fontWeight: FontWeight.w700, color: p.ink),
        subtitleTextStyle: TextStyle(fontFamily: AppType.family, fontSize: AppType.small, height: AppType.bodyHeight, color: p.muted),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontFamily: AppType.family, fontSize: AppType.label, fontWeight: FontWeight.w600, color: p.head),
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
          textStyle: const TextStyle(fontFamily: AppType.family, fontSize: AppType.button, fontWeight: FontWeight.w700),
          shape: buttonShape,
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
          textStyle: const TextStyle(fontFamily: AppType.family, fontSize: AppType.button, fontWeight: FontWeight.w700),
          shape: buttonShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(fontFamily: AppType.family, fontSize: AppType.body, color: p.muted),
        hintStyle: TextStyle(fontFamily: AppType.family, fontSize: AppType.body, color: p.muted),
        helperStyle: TextStyle(fontFamily: AppType.family, fontSize: AppType.small, color: p.muted),
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
            fontFamily: AppType.family,
            fontSize: AppType.tiny,
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
        // Stadium, not CircleBorder: a round button stays round, and a
        // labelled (extended) one becomes a pill instead of a circle that
        // cut its label ("rescrip", "d a me"; owner's screenshots 2026-11-17).
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(fontFamily: AppType.family, color: p.surface, fontSize: AppType.body, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// The app's one type scale (Round 18). Screens take sizes from here or the
/// theme's text styles, never a free number, so the same kind of text has
/// the same size everywhere. Sizes are before the user's Text size setting.
///
/// headline 22 · app bar 19 · title (cards, list rows) 16 · body 15 ·
/// small (help, hints, list subtitles) 13 · tiny (badges, bar labels) 12;
/// big numbers (readings, counts) 28.
class AppType {
  AppType._();

  static const String family = 'HindSiliguri';

  static const double display = 28;
  static const double headline = 22;
  static const double appBar = 19;
  static const double title = 16;
  static const double body = 15;
  static const double label = 14;
  static const double button = 15;
  static const double small = 13;
  static const double tiny = 12;

  /// Hind Siliguri has tall built-in line spacing; these keep two-line text
  /// close (client: "too much space between double lines").
  static const double tightHeight = 1.2;
  static const double bodyHeight = 1.32;

  static TextTheme textTheme(AppPalette p) => TextTheme(
        displaySmall: TextStyle(fontSize: display, height: tightHeight, fontWeight: FontWeight.w700, color: p.head),
        headlineMedium: TextStyle(fontSize: 24, height: tightHeight, fontWeight: FontWeight.w700, color: p.head),
        headlineSmall: TextStyle(fontSize: headline, height: tightHeight, fontWeight: FontWeight.w700, color: p.head),
        titleLarge: TextStyle(fontSize: appBar, height: tightHeight, fontWeight: FontWeight.w700, color: p.head),
        titleMedium: const TextStyle(fontSize: title, height: tightHeight, fontWeight: FontWeight.w700),
        titleSmall: const TextStyle(fontSize: label, height: tightHeight, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(fontSize: 16, height: bodyHeight),
        bodyMedium: const TextStyle(fontSize: body, height: bodyHeight),
        bodySmall: TextStyle(fontSize: small, height: bodyHeight, color: p.muted),
        labelLarge: const TextStyle(fontSize: label, height: tightHeight, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontSize: small, height: tightHeight, fontWeight: FontWeight.w600),
        labelSmall: const TextStyle(fontSize: tiny, height: tightHeight, fontWeight: FontWeight.w600),
      );
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
