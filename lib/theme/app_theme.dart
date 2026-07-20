import 'package:flutter/material.dart';

const kPrimaryPurple = Color(0xFF7E57C2);

ThemeMode resolveThemeMode(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

ThemeData buildLightTheme(int seedColor) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(seedColor),
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(seedColor),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    useMaterial3: true,
  );
}

ThemeData buildDarkTheme(int seedColor) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(seedColor),
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(seedColor),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    useMaterial3: true,
  );
}
