import 'starred_people.dart';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/friendship.dart';

/// Session-only directory cache, cleared when the authenticated account changes.
class PeopleCache extends ChangeNotifier {
  static final instance = PeopleCache();
  String? userId;
  List<FriendshipUser>? following;
  bool failed = false;
  Future<void>? _pending;
  int _revision = 0;

  void selectAccount(String? id) {
    if (userId == id) return;
    userId = id;
    StarredPeople.instance.selectAccount(id);
    following = null;
    failed = false;
    _pending = null;
    _revision++;
  }

  Future<void> load(Future<List<FriendshipUser>> Function() loader,
      {bool refresh = false}) {
    if (!refresh && following != null) return Future.value();
    if (_pending != null) return _pending!;
    final revision = _revision;
    late final Future<void> work;
    work = () async {
      try {
        final result = await loader();
        if (revision != _revision) return;
        following = List.unmodifiable(result);
        failed = false;
      } catch (_) {
        if (revision == _revision) failed = true;
      } finally {
        if (revision == _revision) {
          _pending = null;
          notifyListeners();
        }
      }
    }();
    _pending = work;
    return work;
  }

  void remove(String id) {
    // Invalidate reads begun before the successful mutation.
    _revision++;
    _pending = null;
    if (following != null) {
      following = List.unmodifiable(following!.where((u) => u.id != id));
    }
    notifyListeners();
  }

  void invalidateRead() {
    _revision++;
    _pending = null;
  }
}
