import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/utils/app_logger.dart';

/// Independent optional requests, retries and stale-response protection.
///
/// The screen supplies request/application callbacks and the current viewer;
/// this controller has no navigation or BuildContext dependency.
class MovieDetailSectionsController extends ChangeNotifier {
  MovieDetailSectionsController({required this.viewerId});

  final String? Function() viewerId;
  final Map<String, String> _states = {};
  final Map<String, Future<void> Function()> _retries = {};
  final Set<String> _loaded = {};
  late final Map<String, String> states = UnmodifiableMapView(_states);
  late final Map<String, Future<void> Function()> retries =
      UnmodifiableMapView(_retries);
  late final Set<String> loaded = UnmodifiableSetView(_loaded);
  final Map<String, int> _attempts = {};
  int _generation = 0;
  bool _disposed = false;

  void begin({required bool clearLoaded}) {
    _generation++;
    _states.clear();
    _retries.clear();
    _attempts.clear();
    if (clearLoaded) _loaded.clear();
  }

  Future<void> load<T>(
      String key, Future<T> Function() fetch, void Function(T) apply) async {
    if (_disposed) return;
    final generation = _generation;
    final viewer = viewerId();
    final attempt = (_attempts[key] ?? 0) + 1;
    _attempts[key] = attempt;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        attempt == _attempts[key] &&
        viewer == viewerId();
    _states[key] = 'loading';
    _retries[key] = () => load(key, fetch, apply);
    notifyListeners();
    try {
      final value = await fetch();
      if (!current()) return;
      apply(value);
      _loaded.add(key);
      _states.remove(key);
      notifyListeners();
    } catch (error) {
      if (!current()) return;
      apiLogger.w('Movie detail section $key failed: $error');
      _states[key] = 'error';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retries.clear();
    super.dispose();
  }
}
