import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';
import '../../data/watch_requests_service.dart';
import '../../data/watch_request_cache.dart';
import '../../data/watch_plan_visibility_store.dart';

/// One viewer and one route's plans. Widgets own navigation and sheets.
class WatchRequestsController extends ChangeNotifier {
  WatchRequestsController(
      {required this.auth,
      this.focusedId,
      WatchRequestCache? cache,
      this.service = const WatchRequestsService()})
      : viewer = auth.dbUser?.id {
    if (!isFocused) {
      final cached = auth.cachedWatchRequests ??
          (cache?.hasDirectSnapshot == true ? cache!.direct : null);
      _requests = List.of(cached ?? const []);
      loading = cached == null;
      groups = List.of(auth.cachedGroups ?? []);
      loadingGroups = groups.isEmpty;
    }
  }
  final AuthProvider auth;
  final WatchRequestsService service;
  final String? viewer;
  final String? focusedId;
  List<WatchRequest> _requests = [];
  List<WatchRequest> get requests => List.unmodifiable(_requests);
  List<Group> groups = [];
  Set<String> _closed = {};
  final Map<String, FriendWatchPlanAction> _busy = {};
  final Map<String, Set<String>> _drafts = {};
  final Set<String> _dirty = {};
  bool loading = true;
  bool loadingGroups = false;
  String? error;
  int groupActiveCount = 0;
  WatchPlanFilter filter = WatchPlanFilter.active;
  String query = '';
  int _generation = 0;
  int _groupsGeneration = 0;
  int _closedGeneration = 0;
  int get revision => _generation;
  bool _disposed = false;
  bool get owns => !_disposed && auth.dbUser?.id == viewer;
  bool get isFocused => focusedId?.isNotEmpty == true;
  bool busy(String id) => _busy.containsKey(id);
  bool matches(WatchRequest r, WatchPlanFilter f) =>
      WatchPlanDisplayState.matchesFilter(r, f, viewer ?? '');
  int count(WatchPlanFilter f) => _requests.where((r) => matches(r, f)).length;
  List<WatchRequest> get filtered => _requests.where((r) {
        if (isFocused) return r.id == focusedId;
        if (_closed.contains(r.id) || !matches(r, filter)) return false;
        final q = query.toLowerCase();
        return q.isEmpty ||
            (r.movie?.title.toLowerCase().contains(q) ?? false) ||
            (r.otherUser(viewer ?? '')?.username.toLowerCase().contains(q) ??
                false);
      }).toList(growable: false);

  Future<void> start() async {
    await Future.wait([load(), loadClosed(), if (!isFocused) loadGroups()]);
  }

  void setFilter(WatchPlanFilter value) {
    filter = value;
    _publish();
  }

  void setQuery(String value) {
    query = value;
    _publish();
  }

  void setGroupActiveCount(int value) {
    if (groupActiveCount == value) return;
    groupActiveCount = value;
    _publish();
  }

  void _publish() {
    if (owns) notifyListeners();
  }

  Future<void> load({bool showSpinner = false}) async {
    if (!owns) return;
    if (viewer == null || viewer!.isEmpty) {
      loading = false;
      _publish();
      return;
    }
    final generation = ++_generation;
    bool current() => owns && generation == _generation;
    if (showSpinner) loading = true;
    error = null;
    _publish();
    try {
      List<WatchRequest> loaded;
      if (isFocused) {
        try {
          loaded = [
            await service.focused(
                viewer!, focusedId!, 'watch-plan:$hashCode:$generation')
          ];
        } catch (e) {
          if (!current()) return;
          logger.w('Focused Watch Plan lookup failed; trying direct list: $e');
          loaded = await service.load(viewer!);
        }
      } else {
        loaded = await service.load(viewer!);
      }
      if (!current()) return;
      loaded = List.of(loaded)
        ..sort((a, b) => (DateTime.tryParse(b.createdAt ?? '') ??
                DateTime(1970))
            .compareTo(DateTime.tryParse(a.createdAt ?? '') ?? DateTime(1970)));
      _requests = loaded;
      loading = false;
      if (isFocused) {
        final cached = List<WatchRequest>.of(auth.cachedWatchRequests ?? []);
        for (final item in loaded) {
          cached.removeWhere((r) => r.id == item.id);
          cached.add(item);
        }
        auth.updateCachedWatchRequests(cached);
      } else {
        auth.updateCachedWatchRequests(loaded);
      }
      _publish();
      for (final request in loaded) {
        if (!current()) return;
        final scheduled = request.scheduledFor;
        if (request.isTerminal ||
            scheduled == null ||
            (isFocused && request.normalizedScheduleStatus != 'AGREED') ||
            watchPlanScheduleHasPassed(scheduled,
                dateOnly: request.scheduledDateOnly)) {
          continue;
        }
        await PushNotificationService.scheduleWatchPlanReminders(
          planId: request.id,
          scheduledFor: scheduled,
          dateOnly: request.scheduledDateOnly,
          title: request.watchPlanTitle,
          withName: request.otherUser(viewer!)?.username ?? 'your friend',
          deepLink: '/watch-requests/${request.id}',
        );
      }
    } catch (e) {
      if (!current()) return;
      logger.w('Watch Plans load failed: $e');
      if (_requests.isEmpty) error = 'Failed to load Watch Plans.';
      loading = false;
      _publish();
    }
  }

  Future<void> loadClosed() async {
    if (!owns || viewer == null) return;
    final generation = ++_closedGeneration;
    final ids = await service.closed(viewer!);
    if (!owns || generation != _closedGeneration) return;
    _closed = ids;
    _publish();
  }

  Future<void> loadGroups() async {
    if (!owns || viewer == null || isFocused) return;
    final generation = ++_groupsGeneration;
    bool current() => owns && generation == _groupsGeneration;
    try {
      final loaded = await service.groups(viewer!);
      if (!current()) return;
      groups = loaded;
      loadingGroups = false;
      _publish();
      final count = await service.activeCount(loaded, current: current);
      if (!current()) return;
      groupActiveCount = count;
      _publish();
    } catch (e) {
      if (!current()) return;
      logger.w('Watch Plans group count failed: $e');
      loadingGroups = false;
      _publish();
    }
  }

  void replace(WatchRequest updated) {
    if (!owns) return;
    _generation++;
    _requests = _requests.map((r) => r.id == updated.id ? updated : r).toList();
    loading = false;
    auth.updateCachedWatchRequests(_requests);
    _publish();
    TabRefreshController.requestHomeRefresh();
  }

  void remove(String id) {
    if (!owns) return;
    _generation++;
    _requests = _requests.where((r) => r.id != id).toList();
    loading = false;
    auth.updateCachedWatchRequests(_requests);
    final notifications = auth.cachedNotifications;
    if (notifications != null) {
      auth.updateCachedNotifications(
          notifications.where((n) => n.linkedRequestId != id).toList());
    }
    clearDraft(id);
    _publish();
    TabRefreshController.requestHomeRefresh();
  }

  Future<void> close(String id) async {
    if (!owns || viewer == null) return;
    _closedGeneration++;
    await WatchPlanVisibilityStore.closePlan(viewer!, id);
    if (!owns) return;
    _closed = {..._closed, id};
    _publish();
  }

  Future<void> runAction(String id, FriendWatchPlanAction action,
      Future<void> Function() run) async {
    if (!owns || busy(id)) return;
    _busy[id] = action;
    _publish();
    try {
      await run();
    } finally {
      if (owns) {
        _busy.remove(id);
        _publish();
      }
    }
  }

  Set<String> draft(WatchRequest request, String userId) {
    if (!_dirty.contains(request.id)) {
      final ids = request.candidates
          .where((c) => c.selectedBy(userId))
          .map((c) => c.id)
          .toSet();
      if (ids.isEmpty && request.candidates.length == 1) {
        ids.add(request.candidates.single.id);
      }
      _drafts[request.id] = ids;
    }
    return Set.of(_drafts[request.id] ?? {});
  }

  void toggle(WatchRequest request, String userId, String candidate) {
    if (!owns) return;
    final ids = draft(request, userId);
    if (!ids.add(candidate)) ids.remove(candidate);
    _drafts[request.id] = ids;
    _dirty.add(request.id);
    _publish();
  }

  void clearDraft(String id) {
    _drafts.remove(id);
    _dirty.remove(id);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _groupsGeneration++;
    super.dispose();
  }
}
