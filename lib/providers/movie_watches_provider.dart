import 'package:flutter/foundation.dart';

import '../models/movie_watch_entry.dart';
import '../repositories/movie_features_repository.dart';
import '../services/api_client.dart';

class MovieWatchesProvider extends ChangeNotifier {
  MovieWatchesProvider({
    required this.repository,
    required this.userId,
  });

  final MovieFeaturesRepository repository;
  final String userId;

  List<MovieWatchEntry> userWatches = [];
  final Map<int, List<MovieWatchEntry>> movieWatches = {};
  bool isLoading = false;
  String? error;

  Future<void> loadAllWatches() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      userWatches = await repository.getUserMovieWatches(userId);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMovieHistory(int movieId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      movieWatches[movieId] = await repository.getMovieWatchHistory(userId, movieId);
    } catch (e) {
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<MovieWatchEntry?> logWatch({
    required int movieId,
    String? watchedAt,
    double? rating,
    String? notes,
  }) async {
    try {
      final created = await repository.logMovieWatch(
        userId,
        movieId: movieId,
        watchedAt: watchedAt,
        rating: rating,
        notes: notes,
      );
      userWatches = [created, ...userWatches];
      movieWatches[movieId] = [created, ...(movieWatches[movieId] ?? [])];
      notifyListeners();
      return created;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<MovieWatchEntry?> updateWatch(
    String watchEntryId, {
    required int movieId,
    String? watchedAt,
    double? rating,
    String? notes,
  }) async {
    try {
      final updated = await repository.updateMovieWatch(
        userId,
        watchEntryId,
        watchedAt: watchedAt,
        rating: rating,
        notes: notes,
      );
      userWatches = userWatches.map((e) => e.id == watchEntryId ? updated : e).toList();
      movieWatches[movieId] =
          (movieWatches[movieId] ?? []).map((e) => e.id == watchEntryId ? updated : e).toList();
      notifyListeners();
      return updated;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteWatch(String watchEntryId, int movieId) async {
    try {
      await repository.deleteMovieWatch(userId, watchEntryId);
      userWatches = userWatches.where((e) => e.id != watchEntryId).toList();
      movieWatches[movieId] =
          (movieWatches[movieId] ?? []).where((e) => e.id != watchEntryId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }
}
