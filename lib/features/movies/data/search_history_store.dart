import 'package:shared_preferences/shared_preferences.dart';

/// The existing five-item, device-local search history (not account data).
class SearchHistoryStore {
  static const key = 'device_recent_searches_v1';
  static const limit = 5;
  Future<void> _writes = Future.value();

  Future<List<String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(key) ?? [];
    final recent = stored.take(limit).toList();
    if (stored.length > limit) await write(recent);
    return recent;
  }

  Future<void> write(List<String> values) {
    final snapshot = List<String>.of(values);
    return _writes = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, snapshot);
    });
  }
}
