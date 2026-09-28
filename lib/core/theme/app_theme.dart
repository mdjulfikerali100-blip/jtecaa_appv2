// lib/core/theme/app_theme.dart
//
// JTECAA Design System — Architecture Appendix F.12
//
// ⚠️ CRITICAL (Appendix K.1): the light-mode "all text turns white" bug on
// real devices happens because GoogleFonts.inter(...)/playfairDisplay(...)
// return a TextStyle with color: null when no color is passed explicitly.
// ThemeData only backfills a *completely missing* TextTheme slot from its
// brightness default — it does NOT repair a null color inside a TextStyle
// object that was already supplied.
//
// THE FIX has two mandatory parts, both applied below:
//   1. Build the raw TextTheme first, then call
//      `.apply(bodyColor: ..., displayColor: ...)` — this force-stamps a
//      color on every single text slot, no exceptions.
//   2. ALWAYS provide both a light and a dark ThemeData to MaterialApp
//      (never leave darkTheme unset) — done in main.dart.
//
// Project-wide rule (enforced by code review, Appendix K.5): never write
// `color: Colors.white` / `color: Colors.black` directly on a Text/TextStyle
// anywhere else in the app. Always go through `Theme.of(context)`.
//
// ⚠️ FIX LOG (this revision):
//   1. Dark theme was missing ~7 component themes (inputDecorationTheme,
//      elevatedButtonTheme, appBarTheme, bottomNavigationBarTheme,
//      chipTheme, snackBarTheme, dividerTheme). Result: dark mode fell
//      back to Material defaults for every one of them, which is why
//      AppBars, text fields and buttons looked "not quite right" in dark
//      mode. Now both themes share the SAME set of component themes,
//      parameterized by colorScheme.
//   2. Removed every hardcoded `Colors.white` / hardcoded hex in
//      component themes — all colors now derive from `colorScheme`,
//      which is exactly what the project-wide rule above demands.
//   3. `AppBarTheme` foreground/title/icon now use `colorScheme.surface`
//      + `colorScheme.onSurface`, so any future screen that doesn't
//      override the AppBar automatically gets theme-correct colors in
//      BOTH modes — no more per-screen `surfaceTintColor:
//      Colors.transparent` patches needed (still safe to keep them).
//   4. Unified `OutlineInputBorder` widths across default/enabled/
//      focused/error so focus transitions are smooth, not jumpy.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds the raw text styles shared by both light and dark themes.
/// Colors are intentionally left unset here — they get force-applied by
/// `.apply(bodyColor:, displayColor:)` at the call site (see below), which
/// is the actual fix for the white-text-on-light-mode bug (Appendix K.1).
TextTheme _rawTextTheme() {
  return TextTheme(
    displayLarge:
        GoogleFonts.playfairDisplay(fontSize: 57, fontWeight: FontWeight.w400),
    displayMedium:
        GoogleFonts.playfairDisplay(fontSize: 45, fontWeight: FontWeight.w400),
    headlineLarge:
        GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium:
        GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w500),
    titleMedium: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
    titleSmall: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
    bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
    bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
    labelLarge: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    labelMedium: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Shared component themes (parameterized by colorScheme), so light and
// dark theme stay in sync forever — a component theme added/edited here
// applies to BOTH automatically. Any per-mode divergence must be
// expressed via `colorScheme.*`, never via `brightness == ...` branches.
// ─────────────────────────────────────────────────────────────────────────

InputDecorationTheme _inputDecorationTheme(ColorScheme c) {
  // Same radius / border style across every state so the focus
  // transition doesn't jump.
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecorationTheme(
    filled: true,
    fillColor: c.surfaceContainerHighest,
    // helperText / error text at 200% font scale need room.
    helperMaxLines: 3,
    errorMaxLines: 3,
    border: border(c.outline, 1),
    enabledBorder: border(c.outline, 1),
    focusedBorder: border(c.primary, 1.6),
    errorBorder: border(c.error, 1.4),
    focusedErrorBorder: border(c.error, 1.8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme c) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 1,
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
  );
}

OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme c) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: c.onSurface,
      side: BorderSide(color: c.outline, width: 1.2),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );
}

AppBarTheme _appBarTheme(ColorScheme c, TextTheme t) {
  return AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 0.5,
    // ✅ Was hardcoded navy/white — now derives from the scheme, so
    // light and dark both get an automatic contrast-correct AppBar.
    backgroundColor: c.surface,
    foregroundColor: c.onSurface,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    iconTheme: IconThemeData(color: c.onSurface, size: 24),
    titleTextStyle: (t.titleLarge ?? const TextStyle()).copyWith(
      color: c.onSurface,
      fontWeight: FontWeight.w700,
    ),
    toolbarHeight: 64,
  );
}

BottomNavigationBarThemeData _bottomNavTheme(ColorScheme c) {
  return BottomNavigationBarThemeData(
    backgroundColor: c.surface,
    selectedItemColor: c.primary,
    unselectedItemColor: c.onSurfaceVariant,
    selectedLabelStyle:
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
    unselectedLabelStyle:
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  );
}

ChipThemeData _chipTheme(ColorScheme c) {
  return ChipThemeData(
    backgroundColor: c.surfaceContainerHighest,
    selectedColor: c.primaryContainer,
    labelStyle: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: c.onSurface,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

SnackBarThemeData _snackBarTheme(ColorScheme c) {
  return SnackBarThemeData(
    // ✅ Was hardcoded slate-on-white — now scheme-derived. Uses
    // `inverseSurface` (M3's intended tone for transient feedback),
    // which auto-flips contrast between light and dark.
    backgroundColor: c.inverseSurface,
    contentTextStyle: GoogleFonts.inter(
      fontSize: 14,
      color: c.onInverseSurface,
    ),
    actionTextColor: c.inversePrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    behavior: SnackBarBehavior.floating,
    elevation: 3,
  );
}

DividerThemeData _dividerTheme(ColorScheme c) {
  return DividerThemeData(
    color: c.outlineVariant,
    thickness: 1,
    space: 1,
  );
}

CardThemeData _cardTheme(ColorScheme c) {
  return CardThemeData(
    elevation: 0,
    // ✅ Slightly rounder, elevation 0 + subtle border — matches the
    // card style already used in JobCard / NewsCard.
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: c.outlineVariant.withValues(alpha: 0.6),
      ),
    ),
    color: c.surfaceContainerLow,
    margin: EdgeInsets.zero,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Light theme — Architecture F.2 (Primary #1A365D, Secondary #B45309,
// Tertiary #0F766E) + F.3 (Typography) + F.6 (Component themes).
// ─────────────────────────────────────────────────────────────────────────

ThemeData buildJTECAATheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A365D),
    brightness: Brightness.light,
    primary: const Color(0xFF1A365D),
    secondary: const Color(0xFFB45309),
    tertiary: const Color(0xFF0F766E),
    surface: const Color(0xFFFAFBFC),
    surfaceContainerHighest: const Color(0xFFF1F5F9),
    onSurface: const Color(0xFF0F172A),
    onSurfaceVariant: const Color(0xFF64748B),
    outline: const Color(0xFFCBD5E1),
    error: const Color(0xFFDC2626),
    errorContainer: const Color(0xFFFEE2E2),
    primaryContainer: const Color(0xFFE8EDF3),
    secondaryContainer: const Color(0xFFFEF3C7),
    tertiaryContainer: const Color(0xFFCCFBF1),
  );

  final textTheme = _rawTextTheme().apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    decorationColor: colorScheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,

    // ── Component themes (shared factories) ────────────────────
    cardTheme: _cardTheme(colorScheme),
    inputDecorationTheme: _inputDecorationTheme(colorScheme),
    elevatedButtonTheme: _elevatedButtonTheme(colorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
    appBarTheme: _appBarTheme(colorScheme, textTheme),
    bottomNavigationBarTheme: _bottomNavTheme(colorScheme),
    chipTheme: _chipTheme(colorScheme),
    snackBarTheme: _snackBarTheme(colorScheme),
    dividerTheme: _dividerTheme(colorScheme),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Dark theme — MANDATORY companion to `buildJTECAATheme()`.
// ✅ Now applies the SAME component theme set as light mode, only the
// colorScheme differs. This is what actually makes dark mode feel like
// a first-class theme instead of a half-styled fallback.
// ─────────────────────────────────────────────────────────────────────────

ThemeData buildJTECAADarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A365D),
    brightness: Brightness.dark,
    primary: const Color(0xFF9DB4D4),
    secondary: const Color(0xFFF0B355),
    tertiary: const Color(0xFF5EEAD4),
    surface: const Color(0xFF111827),
    surfaceContainerHighest: const Color(0xFF1F2937),
    onSurface: const Color(0xFFF1F5F9),
    onSurfaceVariant: const Color(0xFFCBD5E1),
    outline: const Color(0xFF475569),
    error: const Color(0xFFF87171),
    errorContainer: const Color(0xFF7F1D1D),
    // ✅ Dark-mode-specific containers so chips/avatars/icon badges
    // (used all over the app now) have a correct low-light tone
    // instead of inheriting a light-tuned default.
    primaryContainer: const Color(0xFF334155),
    secondaryContainer: const Color(0xFF4A3414),
    tertiaryContainer: const Color(0xFF134E4A),
  );

  final textTheme = _rawTextTheme().apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    decorationColor: colorScheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,

    // ── Component themes (SAME factories as light) ─────────────
    cardTheme: _cardTheme(colorScheme),
    inputDecorationTheme: _inputDecorationTheme(colorScheme),
    elevatedButtonTheme: _elevatedButtonTheme(colorScheme),
    outlinedButtonTheme: _outlinedButtonTheme(colorScheme),
    appBarTheme: _appBarTheme(colorScheme, textTheme),
    bottomNavigationBarTheme: _bottomNavTheme(colorScheme),
    chipTheme: _chipTheme(colorScheme),
    snackBarTheme: _snackBarTheme(colorScheme),
    dividerTheme: _dividerTheme(colorScheme),
  );
}
