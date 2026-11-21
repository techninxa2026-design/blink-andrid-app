import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

enum BlinkMood { studio, community, business, exchange, adventure, rewards }

class BlinkMoodColors {
  static Color primary(BlinkMood mood) {
    switch (mood) {
      case BlinkMood.community: return const Color(0xFFEE3264);
      case BlinkMood.business: return const Color(0xFF1A5564);
      case BlinkMood.exchange: return const Color(0xFF4C61B8);
      case BlinkMood.adventure: return const Color(0xFF007E9C);
      case BlinkMood.rewards: return const Color(0xFFAF6913);
      case BlinkMood.studio: return BlinkColors.orangeDark;
    }
  }

  static List<Color> gradient(BlinkMood mood) {
    switch (mood) {
      case BlinkMood.community:
        return const [Color(0xFF391831), Color(0xFF872B57), Color(0xFFE85C5B)];
      case BlinkMood.business:
        return const [Color(0xFF102B38), Color(0xFF164B58), Color(0xFF2B6E69)];
      case BlinkMood.exchange:
        return const [Color(0xFF222243), Color(0xFF4C4280), Color(0xFFDC754B)];
      case BlinkMood.adventure:
        return const [Color(0xFF083E4E), Color(0xFF126E81), Color(0xFFEE8B5B)];
      case BlinkMood.rewards:
        return const [Color(0xFF382413), Color(0xFF975415), Color(0xFFE2A342)];
      case BlinkMood.studio:
        return const [Color(0xFF271D22), Color(0xFFA83B24), BlinkColors.orange];
    }
  }

  static BlinkMood infer(String? eyebrow) {
    final label = (eyebrow ?? '').toUpperCase();
    if (label.contains('BUSINESS') || label.contains('PROFESSION') ||
        label.contains('NETWORK') || label.contains('MEETING')) {
      return BlinkMood.business;
    }
    if (label.contains('EXCHANGE') || label.contains('NEGOTIAT') ||
        label.contains('OFFER')) return BlinkMood.exchange;
    if (label.contains('IRL') || label.contains('PLAN') ||
        label.contains('MEETUP')) return BlinkMood.adventure;
    if (label.contains('BP') || label.contains('REWARD') ||
        label.contains('WALLET')) return BlinkMood.rewards;
    if (label.contains('HEART') || label.contains('CONNECTION') ||
        label.contains('FRIEND') || label.contains('CHECK') ||
        label.contains('PEOPLE')) return BlinkMood.community;
    return BlinkMood.studio;
  }
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
      toolbarHeight: 60,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: Color(0xFFFFE7D9))),
      iconTheme: IconThemeData(color: BlinkColors.orangeDark, size: 23),
      actionsIconTheme: IconThemeData(color: BlinkColors.orangeDark, size: 22),
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
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFFFE4D5), width: 1.2),
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: const DividerThemeData(color: BlinkColors.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFDFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      hintStyle: const TextStyle(color: BlinkColors.muted, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: BlinkColors.orangeDark,
        fontWeight: FontWeight.w800, fontSize: 13),
      prefixIconColor: BlinkColors.orangeDark,
      suffixIconColor: BlinkColors.orangeDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFF0DCD0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFF0DCD0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: BlinkColors.orange, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BlinkColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w800,
          fontSize: 13, letterSpacing: .1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BlinkColors.orangeDark,
        side: const BorderSide(color: Color(0xFFFFC9AC)),
        minimumSize: const Size(0, 46),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BlinkColors.orangeDark,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: BlinkColors.orangeDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(color: BlinkColors.ink,
        fontSize: 13.5, fontWeight: FontWeight.w800),
      subtitleTextStyle: const TextStyle(color: BlinkColors.muted,
        fontSize: 11.8, height: 1.35),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFFFFDFB),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFFFFDFB),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: BlinkColors.orangeSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFFFF8F4),
      selectedColor: BlinkColors.orangeSoft,
      side: const BorderSide(color: Color(0xFFFFD7C1)),
      labelStyle: const TextStyle(color: BlinkColors.ink,
        fontSize: 11.5, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BlinkColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}


/// Web-aligned, persistent light/dark appearance.
final blinkAppearance = BlinkAppearance();
class BlinkAppearance extends ChangeNotifier {
  static const _storageKey = 'blink-theme';
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString(_storageKey) == 'dark'
        ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> choose(ThemeMode selected) async {
    if (selected == ThemeMode.system) selected = ThemeMode.light;
    if (_mode == selected) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, selected == ThemeMode.dark ? 'dark' : 'light');
    _mode = selected;
    notifyListeners();
  }
}

/// Preserve Blink's orange identity while giving surfaces and input fields
/// genuine dark backgrounds and readable accessible foregrounds.
ThemeData blinkDarkTheme() {
  const canvas = Color(0xFF11141B);
  const surface = Color(0xFF1B2029);
  const raised = Color(0xFF242B36);
  const outline = Color(0xFF39414D);
  const text = Color(0xFFF4F5F7);
  const muted = Color(0xFFB5BECC);
  final palette = ColorScheme.fromSeed(
    seedColor: BlinkColors.orange,
    brightness: Brightness.dark,
    surface: surface,
    primary: const Color(0xFFFF873E),
    onPrimary: const Color(0xFF201009),
    onSurface: text,
    outline: outline,
  );
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    colorScheme: palette,
    scaffoldBackgroundColor: canvas,
    primaryColor: BlinkColors.orange,
    textTheme: base.textTheme.apply(
      fontFamily: 'Roboto', bodyColor: text, displayColor: text),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface, foregroundColor: text,
      elevation: 0, scrolledUnderElevation: 0, centerTitle: true,
      toolbarHeight: 60, surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: outline)),
      iconTheme: IconThemeData(color: Color(0xFFFF873E)),
      actionsIconTheme: IconThemeData(color: Color(0xFFFF873E)),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface, surfaceTintColor: Colors.transparent,
      elevation: 0, shadowColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: outline),
      ),
    ),
    dividerTheme: const DividerThemeData(color: outline, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: raised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      hintStyle: const TextStyle(color: muted, fontSize: 13),
      labelStyle: const TextStyle(color: muted),
      floatingLabelStyle: const TextStyle(color: Color(0xFFFFA16B)),
      prefixIconColor: const Color(0xFFFFA16B),
      suffixIconColor: const Color(0xFFFFA16B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: outline)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: outline)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFFF873E), width: 1.6)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFFFFA16B),
      titleTextStyle: TextStyle(color: text, fontSize: 13.5,
        fontWeight: FontWeight.w800),
      subtitleTextStyle: TextStyle(color: muted, fontSize: 11.8,
        height: 1.35),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface, surfaceTintColor: Colors.transparent,
      showDragHandle: true, dragHandleColor: Color(0xFFFF873E)),
    chipTheme: ChipThemeData(
      backgroundColor: raised, selectedColor: const Color(0xFF57301F),
      side: const BorderSide(color: outline),
      labelStyle: const TextStyle(color: text, fontSize: 11.5,
        fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFF873E),
        foregroundColor: const Color(0xFF201009),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: raised,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}
