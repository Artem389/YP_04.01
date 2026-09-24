import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    _mode = value == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _mode == ThemeMode.dark ? 'dark' : 'light');
  }
}