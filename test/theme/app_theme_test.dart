import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coy_house_calender/theme/app_theme.dart';

void main() {
  test('resolveThemeMode maps known strings', () {
    expect(resolveThemeMode('light'), ThemeMode.light);
    expect(resolveThemeMode('dark'), ThemeMode.dark);
    expect(resolveThemeMode('system'), ThemeMode.system);
  });

  test('resolveThemeMode falls back to system for unknown value', () {
    expect(resolveThemeMode('weird'), ThemeMode.system);
  });

  test('buildLightTheme uses given seed color with light brightness', () {
    final theme = buildLightTheme(0xFF7E57C2);
    expect(theme.brightness, Brightness.light);
    expect(theme.useMaterial3, true);
  });

  test('buildDarkTheme uses given seed color with dark brightness', () {
    final theme = buildDarkTheme(0xFF7E57C2);
    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, true);
  });
}
