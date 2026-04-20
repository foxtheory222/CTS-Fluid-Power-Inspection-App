import 'package:flutter/material.dart';

class CtsPalette {
  static const navy = Color(0xFF0C2E57);
  static const navyAlt = Color(0xFF103A6A);
  static const ink = Color(0xFF16395F);
  static const slate = Color(0xFF5C7390);
  static const slateMuted = Color(0xFF7B8FA8);
  static const steel = Color(0xFF4D6D95);
  static const secondaryBlue = Color(0xFF1A97D6);
  static const secondaryBlueSoft = Color(0xFFD9EFFA);
  static const secondaryBlueMuted = Color(0xFF157EB4);
  static const orange = secondaryBlue;
  static const orangeSoft = secondaryBlueSoft;
  static const orangeMuted = secondaryBlueMuted;
  static const cloud = Color(0xFFF3F7FA);
  static const mist = Color(0xFFE6EEF5);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF8F9FB);
  static const line = Color(0xFFD5DEE8);
  static const lineSoft = Color(0xFFE6ECF2);
  static const success = Color(0xFF218A63);
  static const warning = Color(0xFFB67A1A);
  static const danger = Color(0xFFC74343);
  static const info = Color(0xFF2478B5);
}

ThemeData buildCtsTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: CtsPalette.secondaryBlue,
          onPrimary: Colors.white,
          secondary: CtsPalette.steel,
          onSecondary: Colors.white,
          error: CtsPalette.danger,
          onError: Colors.white,
          surface: CtsPalette.navy,
          onSurface: Colors.white,
          tertiary: CtsPalette.info,
          onTertiary: Colors.white,
        ).copyWith(
          surfaceContainerHighest: const Color(0xFF16263E),
          onSurfaceVariant: const Color(0xFFB3C1D1),
          outline: const Color(0xFF29405E),
          outlineVariant: const Color(0xFF223652),
          surfaceTint: CtsPalette.secondaryBlue,
        )
      : const ColorScheme.light(
          primary: CtsPalette.secondaryBlue,
          onPrimary: Colors.white,
          secondary: CtsPalette.steel,
          onSecondary: Colors.white,
          error: CtsPalette.danger,
          onError: Colors.white,
          surface: CtsPalette.surface,
          onSurface: CtsPalette.ink,
          tertiary: CtsPalette.info,
          onTertiary: Colors.white,
        ).copyWith(
          surfaceContainerHighest: CtsPalette.mist,
          onSurfaceVariant: CtsPalette.slate,
          outline: CtsPalette.line,
          outlineVariant: CtsPalette.lineSoft,
          surfaceTint: Colors.white,
        );

  const baseTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    displaySmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      height: 1.25,
    ),
    labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
    labelMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
    labelSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? CtsPalette.navy : CtsPalette.cloud,
    fontFamily: 'Inter',
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
      elevation: dark ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.0 : 0.05),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: dark
              ? scheme.outlineVariant
              : Colors.white.withValues(alpha: 0.9),
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF16263E) : Colors.white,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: CtsPalette.orange, width: 1.8),
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
        backgroundColor: CtsPalette.secondaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CtsPalette.secondaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
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
          fontFamily: 'Inter',
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
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: 'Inter',
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
