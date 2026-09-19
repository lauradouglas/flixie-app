import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device appearance preference, loaded before the first app frame.
class AppearanceController extends ChangeNotifier {
  AppearanceController(this._preferences)
      : _mode = switch (_preferences.getString(storageKey)) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        };

  static const storageKey = 'flixie.appearance';
  final SharedPreferences _preferences;
  ThemeMode _mode;
  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode value) async {
    if (value == _mode) return;
    // Persist before changing the UI so a failed write cannot appear saved.
    final saved = await _preferences.setString(storageKey, value.name);
    if (!saved) throw StateError('Could not save appearance');
    _mode = value;
    notifyListeners();
  }
}
