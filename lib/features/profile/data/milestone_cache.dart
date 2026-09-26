import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/profile_milestone.dart';

/// Session-only owner cache. Friend profiles always recheck server permissions.
class MilestoneCache {
  static final instance = MilestoneCache();
  String? _owner;
  int _revision = 0;
  ProfileMilestones? _data;
  DateTime? _fetchedAt;
  Future<ProfileMilestones>? _pending;

  void useOwner(String userId) {
    if (_owner == userId) return;
    clear();
    _owner = userId;
  }

  void clear() {
    invalidate();
    _owner = null;
  }

  void invalidate() {
    _revision++;
    _data = null;
    _fetchedAt = null;
    _pending = null;
  }

  ProfileMilestones? peek(String userId) => userId == _owner ? _data : null;

  Future<void> warm(String userId) async {
    useOwner(userId);
    try {
      await load(userId);
    } catch (_) {
      // Optional startup work; opening the page can retry later.
    }
  }

  Future<ProfileMilestones> load(String userId, {bool refresh = false}) {
    if (userId != _owner) return _fetch(userId);
    if (_pending != null) return _pending!;
    if (!refresh &&
        _data != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < const Duration(minutes: 5)) {
      return Future.value(_data);
    }
    final revision = _revision;
    final request = _fetch(userId).then((value) {
      if (_owner == userId && _revision == revision) {
        _data = value;
        _fetchedAt = DateTime.now();
      }
      return value;
    }).whenComplete(() {
      if (_owner == userId && _revision == revision) _pending = null;
    });
    _pending = request;
    return request;
  }

  Future<ProfileMilestones> _fetch(String userId) async =>
      ProfileMilestones.fromJson(await ApiClient.get(
        '/users/${Uri.encodeComponent(userId)}/milestones',
        requestScope: 'milestones:$_revision',
      ) as Map<String, dynamic>);
}
