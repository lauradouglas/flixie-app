import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/app_icon/app_icon_service.dart';
import '../../data/pip_collection_service.dart';
import '../../models/pip_collection.dart';

class PipCollectionController extends ChangeNotifier
    with WidgetsBindingObserver {
  PipCollectionController(
      {PipCollectionService? service, AppIconService? icons})
      : _service = service ?? PipCollectionService(),
        _icons = icons ?? AppIconService.instance {
    WidgetsBinding.instance.addObserver(this);
  }
  final PipCollectionService _service;
  final AppIconService _icons;
  String? _userId;
  int _generation = 0, _activity = -1;
  bool _disposed = false;
  Future<void>? _loading;
  Future<void> _cacheTail = Future.value();
  PipCollection collection = const PipCollection();
  bool loading = false, saving = false, verified = false;
  String? error;
  String? get userId => _userId;
  void syncUser(String? userId, int activity) {
    if (userId == _userId) {
      if (activity != _activity) {
        _activity = activity;
        scheduleMicrotask(refresh);
      }
      return;
    }
    _userId = userId;
    _activity = activity;
    _generation++;
    collection = const PipCollection();
    error = null;
    verified = false;
    saving = false;
    loading = false;
    _loading = null;
    final generation = _generation;
    scheduleMicrotask(() async {
      if (!_current(generation)) return;
      _notify();
      if (userId == null) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('pip_collection_v1:$userId');
        if (_current(generation) && !verified && cached != null) {
          collection = PipCollection.fromJson(
              Map<String, dynamic>.from(jsonDecode(cached)));
          _notify();
        }
      } catch (_) {/* Cache is optional, never an ownership authority. */}
      if (_current(generation)) await refresh();
    });
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() {
    if (_disposed || _userId == null || saving) return Future.value();
    final generation = _generation;
    return _loading ??= _fetch().whenComplete(() {
      if (_current(generation)) _loading = null;
    });
  }

  Future<void> _fetch() async {
    final generation = _generation, owner = _userId!;
    loading = true;
    error = null;
    _notify();
    try {
      final value = await _service.load();
      if (!_current(generation)) return;
      collection = value;
      verified = true;
      _icons.updateCinemaEntitlement(owner, value.cinemaUnlocked);
      _cacheTail = _cacheTail.then((_) => _cache(owner, value));
    } catch (_) {
      if (_current(generation)) {
        error = 'Couldn’t refresh your Pips. Your saved look is still here.';
      }
    } finally {
      if (_current(generation)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _cache(String owner, PipCollection value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'pip_collection_v1:$owner', jsonEncode(value.toJson()));
    } catch (_) {/* Server selection remains saved. */}
  }

  Future<void> select(String pip) => _save({'activePip': pip});
  Future<void> acknowledge() => _save({'seen': true});
  Future<void> _save(Map<String, dynamic> body) async {
    if (saving || _userId == null) throw StateError('Please wait.');
    if (body['activePip'] == 'og' && (!verified || !collection.ogUnlocked)) {
      throw StateError('OG Pip is for First 100 members.');
    }
    if (body['activePip'] == 'cinemaClub' &&
        (!verified || !collection.cinemaUnlocked)) {
      throw StateError('Refresh your rewards first.');
    }
    final owner = _userId;
    final generation = _generation;
    // Let an in-flight read settle before changing the server selection.
    await _loading;
    if (owner == null || saving || !_current(generation)) {
      throw StateError('Sign in again.');
    }
    saving = true;
    _notify();
    try {
      final value = await _service.update(body);
      if (!_current(generation)) throw StateError('Account changed.');
      collection = value;
      verified = true;
      _icons.updateCinemaEntitlement(owner, value.cinemaUnlocked);
      error = null;
      _cacheTail = _cacheTail.then((_) => _cache(owner, value));
    } finally {
      if (_current(generation)) {
        saving = false;
        _notify();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
