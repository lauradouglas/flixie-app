import 'package:flutter/foundation.dart';

import '../models/movie_wrapped.dart';
import '../repositories/movie_features_repository.dart';
import '../services/api_client.dart';

class MovieWrappedProvider extends ChangeNotifier {
  MovieWrappedProvider({
    required this.repository,
    required this.userId,
  });

  final MovieFeaturesRepository repository;
  final String userId;

  MovieWrapped? wrapped;
  bool isLoading = false;
  String? error;

  Future<void> loadYear(int year) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      wrapped = await repository.getMovieWrapped(userId, year);
    } catch (e) {
      wrapped = null;
      error = _friendlyError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException && e.statusCode == 404) {
      return 'No wrapped data is available for this year.';
    }
    if (e is ApiException) return e.message;
    return e.toString();
  }
}
