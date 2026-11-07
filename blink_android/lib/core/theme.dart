import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand tokens extracted from the supplied Blink Android UI board.
class BlinkColors {
  static const orange = Color(0xFFFF5900);
  static const orangeDark = Color(0xFFE74B00);
  static const orangeSoft = Color(0xFFFFE9DD);
  static const pale = Color(0xFFFFF5ED);
  static const ink = Color(0xFF171719);
  static const muted = Color(0xFF8D8F97);
  static const line = Color(0xFFF0EEEC);
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFFF9F5);
  static const green = Color(0xFF24AA73);
  static const blue = Color(0xFF3478F6);
  static const pink = Color(0xFFF44B6C);
}

ThemeData blinkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BlinkColors.orange,
    primary: BlinkColors.orange,
    surface: Colors.white,
    brightness: Brightness.light,
  );
  final text = ThemeData.light().textTheme.apply(
    fontFamily: 'Roboto',
    bodyColor: BlinkColors.ink,
    displayColor: BlinkColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BlinkColors.canvas,
    textTheme: text.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -.9,
      ),
      headlineMedium: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -.65,
      ),
      titleLarge: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
      ),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: const TextStyle(fontSize: 13.5, height: 1.4),
      bodySmall: const TextStyle(fontSize: 11.5, color: BlinkColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BlinkColors.surface,
      foregroundColor: BlinkColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 58,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
    // Give *every* existing Material Card a cohesive premium surface,
    // including small detail/history cards that use the stock Card widget.
    cardTheme: CardThemeData(
      color: const Color(0xFFFFFDFB),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: const Color(0x1AFF5900),
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFFFDFCC)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: BlinkColors.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      hintStyle: const TextStyle(color: BlinkColors.muted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BlinkColors.orange, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BlinkColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BlinkColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}


/// Blink Orange is temporarily light-only across all app screens.
/// The previous dark-mode preference is intentionally ignored.
final blinkAppearance = BlinkAppearance();
class BlinkAppearance extends ChangeNotifier {
  ThemeMode get mode => ThemeMode.light;
  Future<void> load() async {}
  Future<void> choose(ThemeMode selected) async { notifyListeners(); }
}
