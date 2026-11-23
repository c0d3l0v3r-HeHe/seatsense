import 'package:flutter/material.dart';

/// Black-and-white, Uber-like look. The only colours in the app are the three crowding levels.
class Pal {
  Pal._();
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const fieldLight = Color(0xFFF3F3F3);
  static const lineLight = Color(0xFFE2E2E2);
  static const mutedLight = Color(0xFF545454);
  static const fieldDark = Color(0xFF1E1E1E);
  static const lineDark = Color(0xFF333333);
  static const mutedDark = Color(0xFFB0B0B0);
  static const cardDark = Color(0xFF121212);
}

extension Palette on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get fg => Theme.of(this).colorScheme.onSurface;
  Color get bg => Theme.of(this).colorScheme.surface;
  Color get field => isDark ? Pal.fieldDark : Pal.fieldLight;
  Color get line => isDark ? Pal.lineDark : Pal.lineLight;
  Color get muted => isDark ? Pal.mutedDark : Pal.mutedLight;
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final fg = dark ? Pal.white : Pal.black;
  final bg = dark ? Pal.black : Pal.white;
  final field = dark ? Pal.fieldDark : Pal.fieldLight;
  final line = dark ? Pal.lineDark : Pal.lineLight;
  final muted = dark ? Pal.mutedDark : Pal.mutedLight;
  final scheme = ColorScheme(
    brightness: b,
    primary: fg,
    onPrimary: bg,
    primaryContainer: field,
    onPrimaryContainer: fg,
    secondary: fg,
    onSecondary: bg,
    secondaryContainer: field,
    onSecondaryContainer: fg,
    tertiary: fg,
    onTertiary: bg,
    tertiaryContainer: field,
    onTertiaryContainer: fg,
    error: const Color(0xFFE11900),
    onError: Pal.white,
    errorContainer: dark ? const Color(0xFF3A0E08) : const Color(0xFFFFEFED),
    onErrorContainer: dark ? const Color(0xFFFFB4A8) : const Color(0xFF8A1000),
    surface: bg,
    onSurface: fg,
    onSurfaceVariant: muted,
    surfaceContainerLowest: bg,
    surfaceContainerLow: dark ? Pal.cardDark : Pal.white,
    surfaceContainer: field,
    surfaceContainerHigh: field,
    surfaceContainerHighest: field,
    outline: line,
    outlineVariant: line,
    inverseSurface: fg,
    onInverseSurface: bg,
    inversePrimary: bg,
    shadow: Pal.black,
    scrim: Pal.black,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: dark ? Pal.cardDark : Pal.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: fg,
        foregroundColor: bg,
        disabledBackgroundColor: fg.withValues(alpha: 0.35),
        disabledForegroundColor: bg,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: fg, side: BorderSide(color: line), shape: const StadiumBorder()),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: fg)),
    sliderTheme: SliderThemeData(
      activeTrackColor: fg,
      inactiveTrackColor: line,
      thumbColor: fg,
      overlayColor: fg.withValues(alpha: 0.08),
      valueIndicatorColor: fg,
      valueIndicatorTextStyle: TextStyle(color: bg, fontWeight: FontWeight.w600),
      activeTickMarkColor: bg.withValues(alpha: 0.6),
      inactiveTickMarkColor: muted.withValues(alpha: 0.5),
      trackHeight: 4,
    ),
    dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: fg),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      floatingLabelStyle: TextStyle(color: fg),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fg, width: 1.5)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: bg,
      indicatorColor: fg,
      selectedIconTheme: IconThemeData(color: bg),
      unselectedIconTheme: IconThemeData(color: fg),
      selectedLabelTextStyle: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: muted, fontSize: 12),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: bg, fontSize: 12),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: bg),
    splashFactory: InkRipple.splashFactory,
  );
}
