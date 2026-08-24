import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'user_theme_mode';
  static const String _promptedKey = 'has_prompted_system_theme';
  
  ThemeMode _themeMode = ThemeMode.light;
  bool _hasPromptedSystemTheme = false;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get hasPromptedSystemTheme => _hasPromptedSystemTheme;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _hasPromptedSystemTheme = prefs.getBool(_promptedKey) ?? false;
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(_themeMode);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveTheme(mode);
    notifyListeners();
  }

  Future<void> markThemePrompted() async {
    _hasPromptedSystemTheme = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptedKey, true);
    notifyListeners();
  }
}
