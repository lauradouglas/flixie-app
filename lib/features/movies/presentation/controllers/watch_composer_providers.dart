import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../../data/watch_composer_service.dart';
import '../../utils/group_provider_match.dart';

/// Provider reads shared only within this open composer. Failed reads are retryable.
class WatchComposerProviders extends ChangeNotifier {
  WatchComposerProviders(this.service, this.userId, this.region);
  final WatchComposerService service;
  final String userId, region;
  bool _disposed = false;
  int _friendGeneration = 0, _groupGeneration = 0;
  final Map<String, Future<List<WatchProvider>>> _users = {};
  final Map<int, Future<void>> _movieLoads = {};
  final Map<int, List<WatchProvider>> _movies = {};
  Set<int> myIds = {}, friendIds = {};
  Map<int, int> groupCounts = {};
  Map<String, int> groupNameCounts = {};
  int groupMemberCount = 0;
  bool loadingSelf = false, loadingFriend = false, loadingGroup = false;
  bool movieLoading(int? id) => _movieLoads.containsKey(id);
  List<WatchProvider> forMovie(int? id) => _movies[id] ?? const [];
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<List<WatchProvider>> _user(String id) =>
      _users.putIfAbsent(id, () async {
        try {
          return List.unmodifiable(await service.userProviders(id));
        } catch (_) {
          _users.remove(id);
          rethrow;
        }
      });
  Future<void> loadSelf() async {
    loadingSelf = true;
    _notify();
    try {
      final result = await _user(userId);
      if (!_disposed) myIds = Set.unmodifiable(result.map((p) => p.id));
    } catch (_) {
    } finally {
      if (!_disposed) {
        loadingSelf = false;
        _notify();
      }
    }
  }

  Future<void> loadMovie(int id) {
    if (_disposed || _movies.containsKey(id)) return Future.value();
    return _movieLoads.putIfAbsent(id, () async {
      try {
        final result = await service.movieProviders(id, region);
        if (_disposed) return;
        final values = {
          for (final p in result.where((p) => p.isStreaming)) p.id: p
        }.values.toList()
          ..sort((a, b) => a.displayPriority.compareTo(b.displayPriority));
        _movies[id] = List.unmodifiable(values);
      } catch (_) {
      } finally {
        _movieLoads.remove(id);
        _notify();
      }
    });
  }

  Future<void> selectFriend(String? id) async {
    final generation = ++_friendGeneration;
    friendIds = {};
    loadingFriend = id != null;
    _notify();
    if (id == null) return;
    try {
      final result = await _user(id);
      if (!_disposed && generation == _friendGeneration) {
        friendIds = Set.unmodifiable(result.map((p) => p.id));
      }
    } catch (_) {
    } finally {
      if (!_disposed && generation == _friendGeneration) {
        loadingFriend = false;
        _notify();
      }
    }
  }

  Future<void> selectGroup(String? id) async {
    final generation = ++_groupGeneration;
    groupCounts = {};
    groupNameCounts = {};
    groupMemberCount = 0;
    loadingGroup = id != null;
    _notify();
    if (id == null) return;
    try {
      final members =
          (await service.members(id)).where((m) => m.isAccepted).toList();
      if (_disposed || generation != _groupGeneration) return;
      final lists = await Future.wait(members.map((m) async {
        try {
          return await _user(m.memberId);
        } catch (_) {
          return <WatchProvider>[];
        }
      }));
      if (_disposed || generation != _groupGeneration) return;
      groupCounts = Map.unmodifiable(countGroupProviderMatches(
          lists.map((list) => list.map((p) => p.id))));
      groupNameCounts = Map.unmodifiable(countGroupProviderMatches(
          lists.map((list) => list.map((p) => p.matchKey))));
      groupMemberCount = members.length;
    } catch (_) {
    } finally {
      if (!_disposed && generation == _groupGeneration) {
        loadingGroup = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _users.clear();
    _movies.clear();
    _movieLoads.clear();
    myIds = {};
    friendIds = {};
    groupCounts = {};
    groupNameCounts = {};
    super.dispose();
  }
}
