import 'package:flutter/material.dart';

class CtsPalette {
  static const navy = Color(0xFF051125);
  static const navyAlt = Color(0xFF09182E);
  static const slate = Color(0xFF47607E);
  static const slateMuted = Color(0xFF6B7D93);
  static const orange = Color(0xFFC94F00);
  static const orangeSoft = Color(0xFFFFA24A);
  static const steel = Color(0xFF9FB1C5);
  static const cloud = Color(0xFFE7EDF4);
  static const surface = Color(0xFF0B172A);
  static const surfaceAlt = Color(0xFF102138);
  static const border = Color(0xFF23364D);
  static const success = Color(0xFF087A50);
  static const warning = Color(0xFF945A00);
  static const danger = Color(0xFFC62828);
  static const dangerOnDark = Color(0xFFFF8A80);
  static const info = Color(0xFF1565C0);
}

ThemeData buildCtsTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: CtsPalette.orange,
    onPrimary: Colors.white,
    secondary: CtsPalette.slate,
    onSecondary: Colors.white,
    error: CtsPalette.danger,
    onError: Colors.white,
    surface: dark ? CtsPalette.surface : Colors.white,
    onSurface: dark ? Colors.white : CtsPalette.navy,
    tertiary: CtsPalette.info,
    onTertiary: Colors.white,
    surfaceContainerHighest: dark
        ? CtsPalette.surfaceAlt
        : const Color(0xFFF2F5F8),
    onSurfaceVariant: dark ? CtsPalette.steel : CtsPalette.slate,
    outline: dark ? CtsPalette.border : const Color(0xFFD5DFEA),
    outlineVariant: dark ? CtsPalette.border : const Color(0xFFE4EAF1),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: dark ? Colors.white : CtsPalette.navy,
    onInverseSurface: dark ? CtsPalette.navy : Colors.white,
    inversePrimary: CtsPalette.orangeSoft,
    surfaceTint: CtsPalette.orange,
  );

  const baseTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
    ),
    displayMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
    ),
    displaySmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: 'PublicSans',
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: dark ? CtsPalette.navy : const Color(0xFFF4F7FB),
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
      color: dark ? CtsPalette.surface : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? CtsPalette.surfaceAlt : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CtsPalette.orange, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CtsPalette.danger, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CtsPalette.danger, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CtsPalette.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CtsPalette.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? CtsPalette.navyAlt : Colors.white,
      indicatorColor: CtsPalette.orange.withValues(alpha: 0.16),
      selectedIconTheme: const IconThemeData(color: CtsPalette.orange),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        color: CtsPalette.orange,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? CtsPalette.surfaceAlt : const Color(0xFFF0F4F9),
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
