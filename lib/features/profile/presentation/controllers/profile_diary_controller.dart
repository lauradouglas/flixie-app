import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../../data/profile_data_service.dart';
import '../diary/diary_selection.dart';

/// On-demand own diary; stale account/request results never publish.
class ProfileDiaryController extends ChangeNotifier {
  ProfileDiaryController(
      {required this.auth, this.service = const ProfileDataService()}) {
    _viewer = auth.dbUser?.id;
    _version = auth.activityVersion;
    auth.addListener(_authChanged);
  }
  final AuthProvider auth;
  final ProfileDataService service;
  String? _viewer;
  int _generation = 0, _version = 0;
  bool _disposed = false;
  Future<void>? _task;
  bool loading = false, failed = false, loaded = false;
  DiarySelection selection = DiarySelection([]);
  void _authChanged() {
    if (_disposed) return;
    if (_viewer != auth.dbUser?.id) {
      _viewer = auth.dbUser?.id;
      _generation++;
      _task = null;
      selection = DiarySelection([]);
      loaded = false;
      failed = false;
      loading = false;
      _version = auth.activityVersion;
      notifyListeners();
      if (_viewer != null) unawaited(load());
    } else if (_version != auth.activityVersion) {
      _version = auth.activityVersion;
      unawaited(load(refresh: true));
    }
  }

  Future<void> load({bool refresh = false}) {
    if (_disposed || _viewer == null) return Future.value();
    if (_task != null && !refresh) return _task!;
    final generation = ++_generation, viewer = _viewer!;
    loading = true;
    failed = false;
    notifyListeners();
    return _task = _load(viewer, generation);
  }

  Future<void> _load(String viewer, int generation) async {
    bool owns() =>
        !_disposed && generation == _generation && viewer == auth.dbUser?.id;
    try {
      final entries = await service.movieWatches(viewer);
      if (owns()) {
        selection = DiarySelection(entries.where((e) => e.userId == viewer));
        loaded = true;
      }
    } catch (_) {
      if (owns()) failed = true;
    } finally {
      if (owns()) {
        loading = false;
        _task = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
