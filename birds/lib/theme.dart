import 'package:flutter/material.dart';

/// Current theme mode of the app (system / light / dark).
/// Any widget can change it: `themeModeNotifier.value = ThemeMode.dark;`
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

const Color _seedColor = Colors.green;

final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.light,
  ),
  useMaterial3: true,
);

final ThemeData darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
);

/// Switches between light and dark, based on what is shown right now.
void toggleTheme(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
}
