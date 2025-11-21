import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadThemeMode();
  }

  static const _themeModeKey = 'theme_mode';

  SharedPreferences? _prefs;

  Future<void> _loadThemeMode() async {
    final prefs = await _getPrefs();
    final storedValue = prefs.getString(_themeModeKey);
    if (storedValue == null) return;
    state = _stringToThemeMode(storedValue);
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _persistAndUpdate(newMode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) return;
    await _persistAndUpdate(mode);
  }

  Future<void> _persistAndUpdate(ThemeMode mode) async {
    final prefs = await _getPrefs();
    await prefs.setString(_themeModeKey, _themeModeToString(mode));
    state = mode;
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _stringToThemeMode(String raw) {
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
}
