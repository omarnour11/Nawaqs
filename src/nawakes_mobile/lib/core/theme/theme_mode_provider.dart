import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefKey = 'nawaqss_theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_prefKey);
      if (modeStr == 'dark') {
        state = ThemeMode.dark;
        AppColors.isDarkMode = true;
      } else if (modeStr == 'light') {
        state = ThemeMode.light;
        AppColors.isDarkMode = false;
      }
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    AppColors.isDarkMode = (newMode == ThemeMode.dark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    AppColors.isDarkMode = (mode == ThemeMode.dark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
