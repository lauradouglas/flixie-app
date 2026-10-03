import 'package:flutter/scheduler.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/models/watch_request.dart';
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
  WatchRequestCache({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final Map<String, List<GroupWatchRequest>> _byGroup = {};
  List<WatchRequest> _direct = const [];
  Future<List<WatchRequest>>? _directInFlight;
  DateTime? _directFetchedAt, _homeFetchedAt;
  List<WatchRequest> get direct => List.unmodifiable(_direct);
  bool get hasDirectSnapshot => _directFetchedAt != null;
  bool get hasHomeSnapshot => _homeFetchedAt != null;
  bool _fresh(DateTime? at) =>
      at != null && _now().difference(at) < const Duration(seconds: 30);

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

  void syncUser(String? userId, {bool deferWarm = false}) {
    if (_userId == userId) return;
    _userId = userId;
    _generation++;
    _home = const [];
    _direct = const [];
    _directInFlight = null;
    _directFetchedAt = _homeFetchedAt = null;
    _homeInFlight = null;
    _byGroup.clear();
    _inFlight.clear();
    if (userId == null || userId.isEmpty) {
      notifyListeners();
      return;
    }
    void warm() {
      if (_disposed || _userId != userId) return;
      _preload(userId);
      _preloadDirect();
    }

    if (deferWarm) {
      SchedulerBinding.instance.addPostFrameCallback((_) => warm());
    } else {
      warm();
    }
  }

  Future<void> _preload(String userId) async {
    try {
      await refreshHome();
    } catch (error) {
      logger.w('Watch request preload failed: $error');
    }
  }

  Future<void> _preloadDirect() async {
    try {
      await refreshDirect();
    } catch (error) {
      logger.w('Direct watch plan preload failed: $error');
    }
  }

  Future<List<WatchRequest>> refreshDirect({bool force = true}) {
    if (_disposed || _userId == null || _userId!.isEmpty) {
      return Future.value(const []);
    }
    if (_directInFlight != null) return _directInFlight!;
    if (!force && _fresh(_directFetchedAt)) return Future.value(direct);
    final generation = _generation;
    final request = RequestService.getWatchRequests(_userId!,
            includeHomeState: true,
            activeOnly: true,
            requestScope: 'direct:$_userId:$generation')
        .then((plans) {
      if (_disposed || generation != _generation) return <WatchRequest>[];
      _direct = List.unmodifiable(plans);
      _directFetchedAt = _now();
      notifyListeners();
      return direct;
    }).catchError((Object error) {
      if (!_disposed &&
          generation == _generation &&
          error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        _direct = const [];
        _directFetchedAt = null;
        notifyListeners();
      }
      throw error;
    });
    _directInFlight = request;
    void clear() {
      if (identical(_directInFlight, request)) _directInFlight = null;
    }

    request.then<void>((_) => clear(),
        onError: (Object _, StackTrace __) => clear());
    return request;
  }

  Future<List<HomeGroupWatchPlan>> refreshHome({bool force = true}) {
    if (_disposed || _userId == null || _userId!.isEmpty) {
      return Future.value(const []);
    }
    final existing = _homeInFlight;
    if (existing != null) return existing;
    if (!force && _fresh(_homeFetchedAt)) return Future.value(home);
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
      _homeFetchedAt = _now();
      notifyListeners();
      return home;
    } catch (error) {
      if (!_disposed &&
          generation == _generation &&
          error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        _home = const [];
        _homeFetchedAt = null;
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
