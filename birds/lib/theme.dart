import 'package:flutter/material.dart';

/// Current theme mode of the app.
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

// Midnight Blue + Lavender palette
const Color midnightBlue = Color(0xFF111943);
const Color blue = Color(0xFF293875);
const Color lavender = Color(0xFFC7CBFF);
const Color softWhite = Color(0xFFF0F0FF);

const Color lightBackground = Color(0xFFF5F5FF);
const Color lightCard = Color(0xFFFFFFFF);

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,

  colorScheme: ColorScheme.fromSeed(
    seedColor: blue,
    brightness: Brightness.light,
  ).copyWith(
    primary: blue,
    secondary: Color(0xFF777FC1),
    surface: lightCard,
  ),

  scaffoldBackgroundColor: lightBackground,

  appBarTheme: const AppBarTheme(
    backgroundColor: lightBackground,
    foregroundColor: midnightBlue,
    elevation: 0,
    centerTitle: false,
  ),

  cardTheme: CardThemeData(
    color: lightCard,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: blue,
    foregroundColor: softWhite,
    elevation: 4,
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  colorScheme: ColorScheme.fromSeed(
    seedColor: lavender,
    brightness: Brightness.dark,
  ).copyWith(
    primary: lavender,
    secondary: Color(0xFF929BEA),
    surface: Color(0xFF20243B),
    onSurface: softWhite,
  ),

  scaffoldBackgroundColor: Color(0xFF1E2158),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E2158),
    foregroundColor: Color(0xFFC0C7F6),
    elevation: 0,
    centerTitle: false,
  ),

  cardTheme: CardThemeData(
    color: Color(0xFF20243B),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF293875),
    foregroundColor: lavender,
    elevation: 4,
  ),
);

void toggleTheme(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  themeModeNotifier.value =
      isDark ? ThemeMode.light : ThemeMode.dark;
}
