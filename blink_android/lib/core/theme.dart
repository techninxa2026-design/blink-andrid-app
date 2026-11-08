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


/// Blink Orange is temporarily light-only across all app screens.
/// The previous dark-mode preference is intentionally ignored.
final blinkAppearance = BlinkAppearance();
class BlinkAppearance extends ChangeNotifier {
  ThemeMode get mode => ThemeMode.light;
  Future<void> load() async {}
  Future<void> choose(ThemeMode selected) async { notifyListeners(); }
}
