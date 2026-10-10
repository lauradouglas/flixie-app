import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../data/group_watch_plan_service.dart';
import '../group_watch_plan_selection.dart';

/// Account/route-scoped plans, drafts and refresh coordination. No widget context.
class GroupWatchPlanController extends ChangeNotifier {
  GroupWatchPlanController({this.service = const GroupWatchPlanService()});
  final GroupWatchPlanService service;
  String _userId = '', _groupName = 'your group';
  String? _groupId, _initialId, _selectedId;
  List<GroupWatchRequest> _requests = const [];
  Map<String, List<GroupMember>> _members = const {};
  Map<String, String> _names = const {};
  final Map<String, Set<String>> _drafts = {};
  bool _bound = false,
      _disposed = false,
      _loading = true,
      _processing = false,
      _past = false;
  bool _refreshScheduled = false, _refreshPending = false;
  int _epoch = 0, _loadGeneration = 0;
  Future<void>? _inFlight;
  String? _error;
  String get userId => _userId;
  int get epoch => _epoch;
  bool isCurrent(int epoch) => !_disposed && epoch == _epoch;
  bool get loading => _loading;
  bool get processing => _processing;
  bool get past => _past;
  String? get error => _error;
  List<GroupWatchRequest> get requests => _requests;
  GroupWatchRequest? get selected =>
      _requests.where((r) => r.matchesId(_selectedId ?? '')).firstOrNull;
  GroupPlanViewData view(GroupWatchRequest request) => GroupPlanViewData(
        request: request,
        userId: _userId,
        members: _members[request.id] ??
            _members[request.databaseRequestId] ??
            const [],
        groupName: _names[request.id] ??
            _names[request.databaseRequestId] ??
            _groupName,
      );
  int get activeCount =>
      _requests.where((r) => r.isActive && !view(r).declined).length;
  int get responseCount => _requests
      .where(
        (r) =>
            r.canRespond &&
            r.userId != _userId &&
            !view(r).accepted &&
            !view(r).declined,
      )
      .length;
  int get pastCount =>
      _requests.where((r) => r.isArchived || view(r).declined).length;
  List<GroupWatchRequest> get visiblePlans => _requests
      .where(
        (r) => _past
            ? r.isArchived || view(r).declined
            : r.isActive && !view(r).declined,
      )
      .toList()
    ..sort((a, b) => groupPlanDate(b).compareTo(groupPlanDate(a)));

  void bind({
    required String userId,
    String? groupId,
    String? groupName,
    String? initialId,
  }) {
    if (_disposed) return;
    if (_bound &&
        _userId == userId &&
        _groupId == groupId &&
        _initialId == initialId) {
      _groupName = groupName ?? 'your group';
      return;
    }
    _bound = true;
    _epoch++;
    _loadGeneration++;
    _userId = userId;
    _groupId = groupId;
    _groupName = groupName ?? 'your group';
    _initialId = initialId;
    _selectedId = initialId;
    _requests = const [];
    _members = const {};
    _names = const {};
    _drafts.clear();
    _inFlight = null;
    _processing = false;
    _past = false;
    _error = null;
    _loading = userId.isNotEmpty;
    _refreshScheduled = _refreshPending = false;
    notifyListeners();
    requestRefresh();
  }

  void select(String? id) {
    if (_disposed) return;
    _selectedId = id;
    notifyListeners();
  }

  void showPast(bool value) {
    if (_disposed) return;
    _past = value;
    notifyListeners();
  }

  Set<String> choices(GroupWatchRequest request) => Set.unmodifiable(
        _drafts[request.id] ??
            request.candidates
                .where((c) => c.selectedByUserIds.contains(_userId))
                .map((c) => c.id)
                .toSet(),
      );
  void toggleChoice(GroupWatchRequest request, String id) {
    if (_disposed || _processing) return;
    final draft = _drafts.putIfAbsent(
      request.id,
      () => choices(request).toSet(),
    );
    if (!draft.remove(id)) draft.add(id);
    notifyListeners();
  }

  void clearDraft(String id) => _drafts.remove(id);
  void addChoices(GroupWatchRequest request, Iterable<String> ids) {
    _drafts.putIfAbsent(request.id, () => choices(request).toSet()).addAll(ids);
  }

  /// Coalesce same-turn notifications; newer refreshes may supersede slow reads.
  void requestRefresh() {
    if (_disposed || _userId.isEmpty) return;
    if (_processing) {
      _refreshPending = true;
      return;
    }
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    final epoch = _epoch;
    scheduleMicrotask(() {
      if (!isCurrent(epoch)) return;
      _refreshScheduled = false;
      if (_processing) {
        _refreshPending = true;
        return;
      }
      unawaited(load(force: true));
    });
  }

  Future<void> load({bool force = false}) {
    if (_disposed || _userId.isEmpty) return Future.value();
    if (!force && _inFlight != null) return _inFlight!;
    return _inFlight = _load();
  }

  Future<void> _load() async {
    final epoch = _epoch, generation = ++_loadGeneration;
    final userId = _userId, groupId = _groupId, name = _groupName;
    bool current() => isCurrent(epoch) && generation == _loadGeneration;
    if (_requests.isEmpty) _loading = true;
    notifyListeners();
    try {
      Future<_LoadedGroup> read(String id, String name) async {
        final values = await Future.wait<Object>([
          service.plans(id, 'group-detail:$hashCode:$generation'),
          service.members(id),
        ]);
        return _LoadedGroup(
          name,
          values[0] as List<GroupWatchRequest>,
          (values[1] as List<GroupMember>)
              .where((m) => m.isOwner || m.isAccepted)
              .toList(),
        );
      }

      final List<_LoadedGroup> groups;
      if (groupId != null && groupId.isNotEmpty) {
        groups = [await read(groupId, name)];
      } else {
        final available = await service.groups(userId);
        if (!current()) return;
        groups = await Future.wait(
          available.where((g) => g.id?.isNotEmpty == true).map((g) async {
            try {
              return await read(g.id!, g.name);
            } catch (_) {
              return _LoadedGroup(g.name, const [], const []);
            }
          }),
        );
      }
      if (!current()) return;
      _requests = List.unmodifiable(groups.expand((g) => g.requests));
      _members = Map.unmodifiable({
        for (final g in groups)
          for (final r in g.requests)
            for (final id in {
              r.id,
              if (r.databaseRequestId != null) r.databaseRequestId!,
            })
              id: List<GroupMember>.unmodifiable(g.members),
      });
      _names = Map.unmodifiable({
        for (final g in groups)
          for (final r in g.requests)
            for (final id in {
              r.id,
              if (r.databaseRequestId != null) r.databaseRequestId!,
            })
              id: g.name,
      });
      _drafts.removeWhere((id, _) => !_requests.any((r) => r.id == id));
      for (final request in _requests) {
        final candidates = request.candidates.map((c) => c.id).toSet();
        _drafts[request.id]?.removeWhere((id) => !candidates.contains(id));
      }
      if (_selectedId != null && selected == null) _selectedId = null;
      _error = null;
      _loading = false;
      notifyListeners();
      for (final request in _requests.where(
        (r) => view(r).declined || r.isArchived,
      )) {
        for (final id in {
          request.id,
          request.databaseRequestId ?? request.id,
        }) {
          if (!current()) return;
          await service.cancelReminders(id);
        }
      }
    } catch (_) {
      if (!current()) return;
      _loading = false;
      _error = 'Couldn’t refresh these Watch Plans. Pull down to try again.';
      notifyListeners();
    } finally {
      if (current()) {
        _inFlight = null;
        if (_refreshPending && !_processing) {
          _refreshPending = false;
          requestRefresh();
        }
      }
    }
  }

  /// An old account's completion cannot refresh or publish into the next account.
  Future<bool> run(Future<void> Function() action) async {
    if (_disposed || _processing || _userId.isEmpty) return false;
    final epoch = _epoch;
    _processing = true;
    // A pre-write snapshot must neither publish nor delay the post-write refresh.
    _loadGeneration++;
    _inFlight = null;
    notifyListeners();
    try {
      await action();
      if (!isCurrent(epoch)) return false;
      _refreshPending = false;
      await load(force: true);
      return isCurrent(epoch);
    } finally {
      if (isCurrent(epoch)) {
        _processing = false;
        notifyListeners();
        if (_refreshPending) {
          _refreshPending = false;
          requestRefresh();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _drafts.clear();
    _requests = const [];
    _members = const {};
    _names = const {};
    super.dispose();
  }
}

class _LoadedGroup {
  const _LoadedGroup(this.name, this.requests, this.members);
  final String name;
  final List<GroupWatchRequest> requests;
  final List<GroupMember> members;
}
