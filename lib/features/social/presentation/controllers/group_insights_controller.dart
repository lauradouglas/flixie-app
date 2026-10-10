import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/group_insights.dart';
import '../../data/group_service.dart';

typedef LoadGroupInsights = Future<GroupInsightsResponse> Function(
  String groupId, {
  String? timeWindow,
  int? limit,
});

/// One group's period and loading state, scoped to the current viewer.
class GroupInsightsController extends ChangeNotifier {
  GroupInsightsController({LoadGroupInsights? load})
      : _load = load ?? GroupService.getGroupInsights;
  final LoadGroupInsights _load;
  String? _groupId, _viewerId;
  bool _enabled = true, _bound = false, _disposed = false;
  bool _allTime = false, _loading = true;
  int _generation = 0;
  Future<void>? _inFlight;
  String? _error;
  GroupInsightsResponse _insights = const GroupInsightsResponse();
  bool get allTime => _allTime;
  bool get loading => _loading;
  String? get error => _error;
  GroupInsightsResponse get insights => _insights;

  Future<void> bind(String groupId, {String? viewerId, bool enabled = true}) {
    if (_disposed) return Future.value();
    if (_bound &&
        _groupId == groupId &&
        _viewerId == viewerId &&
        _enabled == enabled) {
      return _inFlight ?? Future.value();
    }
    if (_bound && _viewerId != viewerId) _allTime = false;
    _bound = true;
    _groupId = groupId;
    _viewerId = viewerId;
    _enabled = enabled;
    _invalidate();
    return refresh();
  }

  Future<void> setAllTime(bool value) {
    if (_disposed || _allTime == value) return _inFlight ?? Future.value();
    _allTime = value;
    _invalidate();
    return refresh();
  }

  void _invalidate() {
    _generation++;
    _inFlight = null;
    _insights = const GroupInsightsResponse();
    _error = null;
  }

  /// Share overlapping reads for this exact viewer/group/period; no result cache.
  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (!_enabled || (_groupId?.isEmpty ?? true)) {
      _loading = false;
      notifyListeners();
      return Future.value();
    }
    return _inFlight ??= _refresh();
  }

  Future<void> _refresh() async {
    final generation = _generation;
    bool current() => !_disposed && generation == _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await Future.sync(() => _load(
            _groupId!,
            timeWindow: _allTime ? 'all' : 'month',
          ));
      if (current()) _insights = result;
    } catch (_) {
      if (current()) _error = "Couldn't load group insights";
    } finally {
      if (current()) {
        _inFlight = null;
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidate();
    super.dispose();
  }
}
