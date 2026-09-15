import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One device-wide preference shared by Settings and all show pages.
class EpisodeSpoilerPreference extends ChangeNotifier {
  static final instance = EpisodeSpoilerPreference();
  static const storageKey = 'hide_episode_spoilers';
  bool hide = true;
  bool saving = false;
  bool loaded = false;
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hide = prefs.getBool(storageKey) ?? true;
      loaded = true;
      notifyListeners();
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> setHidden(bool value) async {
    if (saving) return;
    await load();
    final previous = hide;
    saving = true;
    hide = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(storageKey, value)) {
        throw StateError('Preference was not saved');
      }
    } catch (_) {
      hide = previous;
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
