import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/activity_list_item.dart';

/// Private account preference. Only confirmed server changes enter the cache.
class StarredPeople extends ChangeNotifier {
  static final instance = StarredPeople();
  String? _userId;
  Set<String> ids = {};
  bool loaded = false;
  Future<void>? _pending;
  int _revision = 0;
  void selectAccount(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    ids = {};
    loaded = false;
    _pending = null;
    _revision++;
  }

  Future<void> refresh() {
    if (_userId == null) return Future.value();
    if (_pending != null) return _pending!;
    final userId = _userId!, revision = _revision;
    return _pending = () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_userId != userId || revision != _revision) return;
        final key = 'starred-friends:$userId';
        final old = prefs.getStringList(key) ?? [];
        if (old.isNotEmpty) {
          for (var start = 0; start < old.length; start += 1000) {
            await ApiClient.post('/community/stars/import',
                body: {'ids': old.skip(start).take(1000).toList()});
          }
          await prefs.remove(key);
        }
        if (_userId != userId || revision != _revision) return;
        final data = await ApiClient.get('/community/stars') as Map;
        if (_userId != userId || revision != _revision) return;
        final next = (data['ids'] as List).cast<String>().toSet();
        final changed = !setEquals(ids, next);
        ids = next;
        loaded = true;
        if (changed) notifyListeners();
      } finally {
        if (revision == _revision) _pending = null;
      }
    }();
  }

  Future<void> setStar(String id, bool starred) async {
    final userId = _userId;
    if (userId == null) throw StateError('Sign in first');
    await ApiClient.put('/community/profiles/${Uri.encodeComponent(id)}/star',
        body: {'starred': starred});
    if (_userId != userId) return;
    _revision++;
    _pending = null;
    ids = {...ids};
    if (starred) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    notifyListeners();
  }

  List<ActivityListItem> rank(Iterable<ActivityListItem> items) {
    int score(ActivityListItem item) =>
        (DateTime.tryParse(item.timestamp)?.millisecondsSinceEpoch ?? 0) +
        (ids.contains(item.userId)
            ? const Duration(hours: 48).inMilliseconds
            : 0);
    final result = items.toList();
    result.sort((a, b) => score(b).compareTo(score(a)));
    return result;
  }
}
