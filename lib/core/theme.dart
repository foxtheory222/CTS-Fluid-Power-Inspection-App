import 'package:flutter/material.dart';

class CtsPalette {
  static const navy = Color(0xFF002147);
  static const navyAlt = Color(0xFF000A1E);
  static const ink = Color(0xFF191C1D);
  static const slate = Color(0xFF44474E);
  static const slateMuted = Color(0xFF708AB5);
  static const steel = Color(0xFF206393);
  static const secondaryBlue = Color(0xFF007FFF);
  static const secondaryBlueSoft = Color(0xFFD8EAFF);
  static const secondaryBlueMuted = Color(0xFF035584);
  static const orange = secondaryBlue;
  static const orangeSoft = secondaryBlueSoft;
  static const orangeMuted = secondaryBlueMuted;
  static const cloud = Color(0xFFF8F9FA);
  static const mist = Color(0xFFF3F4F5);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF3F4F5);
  static const line = Color(0xFFC4C6CF);
  static const lineSoft = Color(0xFFE1E3E4);
  static const success = Color(0xFF218A63);
  static const warning = Color(0xFFC98208);
  static const danger = Color(0xFFBA1A1A);
  static const info = Color(0xFF206393);
}

ThemeData buildCtsTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: CtsPalette.navy,
          onPrimary: Colors.white,
          secondary: CtsPalette.steel,
          onSecondary: Colors.white,
          error: CtsPalette.danger,
          onError: Colors.white,
          surface: CtsPalette.navy,
          onSurface: Colors.white,
          tertiary: CtsPalette.secondaryBlue,
          onTertiary: Colors.white,
        ).copyWith(
          surfaceContainerHighest: const Color(0xFF16263E),
          onSurfaceVariant: const Color(0xFFB3C1D1),
          outline: const Color(0xFF29405E),
          outlineVariant: const Color(0xFF223652),
          surfaceTint: CtsPalette.secondaryBlue,
        )
      : const ColorScheme.light(
          primary: CtsPalette.navy,
          onPrimary: Colors.white,
          secondary: CtsPalette.steel,
          onSecondary: Colors.white,
          error: CtsPalette.danger,
          onError: Colors.white,
          surface: CtsPalette.surface,
          onSurface: CtsPalette.ink,
          tertiary: CtsPalette.secondaryBlue,
          onTertiary: Colors.white,
        ).copyWith(
          surfaceContainerHighest: const Color(0xFFE7E8E9),
          onSurfaceVariant: CtsPalette.slate,
          outline: CtsPalette.line,
          outlineVariant: CtsPalette.lineSoft,
          surfaceTint: Colors.white,
        );

  const baseTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'WorkSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: 'WorkSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    displaySmall: TextStyle(
      fontFamily: 'WorkSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'WorkSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'WorkSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'WorkSans',
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(fontFamily: 'WorkSans', fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontFamily: 'WorkSans', fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontFamily: 'WorkSans', fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    bodySmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w400,
      height: 1.25,
    ),
    labelLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    labelMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    labelSmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: 0.25,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? CtsPalette.navy : CtsPalette.cloud,
    fontFamily: 'PublicSans',
    textTheme: baseTextTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? CtsPalette.navy : Colors.white,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF12223A) : Colors.white,
      elevation: dark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.0 : 0.04),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF16263E) : CtsPalette.mist,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: CtsPalette.navy, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: CtsPalette.danger, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: CtsPalette.danger, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CtsPalette.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'PublicSans',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CtsPalette.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'PublicSans',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? Colors.white : CtsPalette.ink,
        backgroundColor: dark ? Colors.transparent : Colors.white,
        side: BorderSide(color: dark ? scheme.outlineVariant : CtsPalette.line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'PublicSans',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      useIndicator: true,
      indicatorColor: CtsPalette.secondaryBlue.withValues(alpha: 0.24),
      selectedIconTheme: const IconThemeData(color: Colors.white, size: 22),
      unselectedIconTheme: const IconThemeData(
        color: Color(0xFF90A5BD),
        size: 20,
      ),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: 'PublicSans',
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: 'PublicSans',
        fontWeight: FontWeight.w600,
        color: Color(0xFF90A5BD),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF16263E) : CtsPalette.surfaceAlt,
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
  );
}
