import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';

/// Account-scoped on-device preference and confirmed movie-rating eligibility.
class MovieRatingPrivacy extends ChangeNotifier {
  MovieRatingPrivacy({Future<Set<int>> Function(String)? loadRatings})
      : _loadRatings = loadRatings ?? _fetchRatings;
  static final instance = MovieRatingPrivacy();
  final Future<Set<int>> Function(String) _loadRatings;
  String? userId;
  bool enabled = false;
  bool loaded = false;
  bool saving = false;
  bool ratingsFailed = false;
  int _generation = 0;
  final Set<int> _rated = {};
  final Set<int> _savedDuringLoad = {};
  Future<void>? _loading;
  static String storageKey(String id) => 'rate_movies_first_v1:$id';

  static Future<Set<int>> _fetchRatings(String id) async {
    final data = await ApiClient.get('/users/$id/movies/ratings');
    return (data as List)
        .whereType<Map>()
        .where((r) {
          final rating = num.tryParse('${r['rating']}');
          return rating != null && rating >= 1 && rating <= 10;
        })
        .map((r) => int.tryParse('${r['movieId']}'))
        .whereType<int>()
        .toSet();
  }

  void syncUser(String? id) {
    if (id == userId) return;
    userId = id;
    final generation = ++_generation;
    enabled = false;
    loaded = id == null;
    saving = false;
    ratingsFailed = false;
    _rated.clear();
    _savedDuringLoad.clear();
    _loading = null;
    scheduleMicrotask(() async {
      if (generation != _generation) return;
      notifyListeners();
      if (id == null) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (generation != _generation) return;
        enabled = prefs.getBool(storageKey(id)) ?? false;
        loaded = true;
        notifyListeners();
        if (enabled) await refreshRatings();
      } catch (_) {
        // Do not expose scores if a saved preference cannot be read.
        if (generation == _generation) {
          ratingsFailed = true;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  bool hides(int? movieId, {bool isShow = false, String? ownerId}) {
    if (isShow || userId == null || ownerId == userId) return false;
    if (!loaded) return true;
    return enabled && !_rated.contains(movieId);
  }

  Future<void> setEnabled(bool value) async {
    final id = userId;
    if (id == null || saving || !loaded) return;
    final generation = _generation;
    saving = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(storageKey(id), value)) {
        throw StateError('Preference could not be saved');
      }
      if (generation != _generation) return;
      enabled = value;
      notifyListeners();
      if (value) await refreshRatings();
    } finally {
      if (generation == _generation) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshRatings() {
    if (!enabled || userId == null) return Future.value();
    return _loading ??= _refresh();
  }

  Future<void> _refresh() async {
    final generation = _generation;
    _savedDuringLoad.clear();
    try {
      final ratings = await _loadRatings(userId!);
      if (generation != _generation) return;
      _rated
        ..clear()
        ..addAll(ratings)
        ..addAll(_savedDuringLoad);
      ratingsFailed = false;
    } catch (_) {
      if (generation == _generation) ratingsFailed = true;
    } finally {
      if (generation == _generation) {
        _loading = null;
        notifyListeners();
      }
    }
  }

  void ratingSaved(String id, int movieId, num? rating) {
    if (id != userId || rating == null || rating < 1 || rating > 10) return;
    _savedDuringLoad.add(movieId);
    if (_rated.add(movieId)) notifyListeners();
  }
}

bool hideMovieRatings(BuildContext context, int? movieId,
        {bool isShow = false, String? ownerId}) =>
    context
        .watch<MovieRatingPrivacy?>()
        ?.hides(movieId, isShow: isShow, ownerId: ownerId) ??
    false;
