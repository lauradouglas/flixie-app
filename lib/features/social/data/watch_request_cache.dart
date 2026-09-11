import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/api/api_client.dart';

import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group_watch_request.dart';

/// App-level, memory-backed watch request cache.
///
/// Authentication preloads only the compact Home projection. Full group
/// requests load when the group/plan opens and are never seeded from Home data.
/// Both paths coalesce in-flight reads; explicit refreshes fetch fresh data.
class WatchRequestCache extends ChangeNotifier {
  final Map<String, List<GroupWatchRequest>> _byGroup = {};
  final Map<String, Future<List<GroupWatchRequest>>> _inFlight = {};
  String? _userId;
  int _generation = 0;
  bool _disposed = false;
  List<HomeGroupWatchPlan> _home = const [];
  Future<List<HomeGroupWatchPlan>>? _homeInFlight;
  List<HomeGroupWatchPlan> get home => List.unmodifiable(_home);

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  List<GroupWatchRequest> forGroup(String groupId) =>
      List.unmodifiable(_byGroup[groupId] ?? const <GroupWatchRequest>[]);

  void syncUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _generation++;
    _home = const [];
    _homeInFlight = null;
    _byGroup.clear();
    _inFlight.clear();
    if (userId == null || userId.isEmpty) {
      notifyListeners();
      return;
    }
    _preload(userId);
  }

  Future<void> _preload(String userId) async {
    try {
      await refreshHome();
    } catch (error) {
      logger.w('Watch request preload failed: $error');
    }
  }

  Future<List<HomeGroupWatchPlan>> refreshHome() {
    if (_disposed || _userId == null || _userId!.isEmpty) {
      return Future.value(const []);
    }
    final existing = _homeInFlight;
    if (existing != null) return existing;
    final generation = _generation;
    final request = _fetchHome(generation);
    _homeInFlight = request;
    void clear() {
      if (identical(_homeInFlight, request)) _homeInFlight = null;
    }

    request.then<void>((_) => clear(),
        onError: (Object _, StackTrace __) => clear());
    return request;
  }

  Future<List<HomeGroupWatchPlan>> _fetchHome(int generation) async {
    try {
      final entries = await GroupService.getHomeGroupWatchPlans(
          requestScope: 'home:$_userId:$generation');
      if (_disposed || generation != _generation) return const [];
      _home = List.unmodifiable(entries);
      notifyListeners();
      return home;
    } catch (error) {
      if (!_disposed &&
          generation == _generation &&
          error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        _home = const [];
        _byGroup.clear();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<List<GroupWatchRequest>> refreshGroup(String groupId) {
    final existing = _inFlight[groupId];
    if (existing != null) return existing;

    final request = _fetchGroup(groupId);
    _inFlight[groupId] = request;
    request.then<void>(
      (_) {
        if (identical(_inFlight[groupId], request)) _inFlight.remove(groupId);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_inFlight[groupId], request)) _inFlight.remove(groupId);
      },
    );
    return request;
  }

  Future<List<GroupWatchRequest>> _fetchGroup(String groupId) async {
    final generation = _generation;
    final requests = await GroupService.getGroupWatchRequests(groupId,
        requestScope: 'detail:$_userId:$generation');
    if (_disposed || generation != _generation) return const [];
    _byGroup[groupId] = List.unmodifiable(requests);
    notifyListeners();
    return forGroup(groupId);
  }
}
