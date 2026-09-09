// lib/core/theme/app_theme.dart
//
// JTECAA Design System — Architecture Appendix F.12
//
// ⚠️ CRITICAL (Appendix K.1): the light-mode "all text turns white" bug on
// real devices happens because GoogleFonts.inter(...)/playfairDisplay(...)
// return a TextStyle with color: null when no color is passed explicitly.
// ThemeData only backfills a *completely missing* TextTheme slot from its
// brightness default — it does NOT repair a null color inside a TextStyle
// object that was already supplied. On Chrome, the surrounding
// DefaultTextStyle happens to resolve dark anyway, so this bug is
// invisible with `flutter run -d chrome` and only shows up on a real
// device (`flutter build apk --debug`).
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
// ⚠️ FIX LOG (root cause, not a patch-over):
//   1. `ThemeData.cardTheme` now requires `CardThemeData`, not `CardTheme`
//      — Flutter refactored the *ThemeData family (Card, Dialog, etc.) to
//      dedicated *ThemeData classes as part of the Material 3 rollout
//      (breaking change landed after this Architecture doc was written,
//      SDK-version-dependent). Fixed at every `cardTheme:` call site below
//      instead of only where the analyzer first pointed.
//   2. `ColorScheme.fromSeed(background: ..., surfaceVariant: ...)` are
//      deprecated in current Material 3 guidance — `background` folded
//      into `surface`, and `surfaceVariant` renamed to
//      `surfaceContainerHighest`. Both parameters removed here and every
//      downstream `colorScheme.background` / `colorScheme.surfaceVariant`
//      read replaced with the non-deprecated equivalent, project-wide in
//      this file (not just the line the analyzer flagged first).

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

/// Light theme — Architecture F.2 (Primary #1A365D, Secondary #B45309,
/// Tertiary #0F766E) + F.3 (Typography) + F.6 (Component themes).
ThemeData buildJTECAATheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A365D),
    brightness:
        Brightness.light, // ⚠️ explicit — never leave brightness implicit
    primary: const Color(0xFF1A365D),
    secondary: const Color(0xFFB45309),
    tertiary: const Color(0xFF0F766E),
    surface: const Color(0xFFFAFBFC),
    // ⚠️ FIX: `surfaceVariant` → `surfaceContainerHighest` (deprecated
    // rename, current Material 3 API).
    surfaceContainerHighest: const Color(0xFFF1F5F9),
    // ⚠️ FIX: `background` param removed — deprecated; `surface` above is
    // now the single source of truth for the app's base background color.
    onSurface: const Color(0xFF0F172A),
    onSurfaceVariant: const Color(0xFF64748B),
    outline: const Color(0xFFCBD5E1),
    error: const Color(0xFFDC2626),
    errorContainer: const Color(0xFFFEE2E2),
    primaryContainer: const Color(0xFFE8EDF3),
    secondaryContainer: const Color(0xFFFEF3C7),
    tertiaryContainer: const Color(0xFFCCFBF1),
  );

  // ⚠️ MANDATORY step (Appendix K.1 fix, part 1) — force-stamp color on
  // every text slot instead of trusting ThemeData's brightness backfill.
  final textTheme = _rawTextTheme().apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    decorationColor: colorScheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    // ⚠️ FIX: was `colorScheme.background` (deprecated) — `surface` is now
    // the correct field to read for the scaffold's base background color.
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    // ⚠️ FIX: `CardTheme(...)` → `CardThemeData(...)`. `ThemeData.cardTheme`
    // expects `CardThemeData?` on current Flutter SDKs; passing the old
    // `CardTheme` widget-config class no longer type-checks.
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFF1F5F9),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A365D), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 1,
        backgroundColor: const Color(0xFF1A365D),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 2,
      backgroundColor: const Color(0xFF1A365D),
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
      toolbarHeight: 64,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFFAFBFC),
      selectedItemColor: Color(0xFF1A365D),
      unselectedItemColor: Color(0xFF64748B),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFFE8EDF3),
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF0F172A),
      contentTextStyle:
          GoogleFonts.inter(fontSize: 14, color: const Color(0xFFFAFBFC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      elevation: 3,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFCBD5E1),
      thickness: 1,
      indent: 16,
      endIndent: 16,
    ),
  );
}

/// Dark theme — MANDATORY companion to `buildJTECAATheme()`.
/// ⚠️ Never ship MaterialApp with only a light `theme:` and no
/// `darkTheme:` — that's exactly what causes "dark mode looks fine, light
/// mode is broken" to appear random (Appendix K.1, F.12 explanation).
ThemeData buildJTECAADarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A365D),
    brightness: Brightness.dark,
    primary: const Color(0xFF9DB4D4),
    secondary: const Color(0xFFF0B355),
    tertiary: const Color(0xFF5EEAD4),
    surface: const Color(0xFF111827),
    // ⚠️ FIX: `surfaceVariant` → `surfaceContainerHighest` (see light
    // theme comment above — same rename, same reason).
    surfaceContainerHighest: const Color(0xFF1F2937),
    // ⚠️ FIX: `background` param removed — deprecated; dark `surface`
    // above now covers this role.
    onSurface: const Color(0xFFF1F5F9),
    onSurfaceVariant: const Color(0xFFCBD5E1),
    outline: const Color(0xFF475569),
    error: const Color(0xFFF87171),
    errorContainer: const Color(0xFF7F1D1D),
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
    // ⚠️ FIX: was `colorScheme.background` (deprecated) — see light theme.
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    // ⚠️ FIX: `CardTheme(...)` → `CardThemeData(...)` — see light theme
    // comment above for the full explanation of this breaking change.
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest,
    ),
  );
}
