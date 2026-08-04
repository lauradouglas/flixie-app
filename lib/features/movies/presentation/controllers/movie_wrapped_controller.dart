import 'package:flutter/foundation.dart';

import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/core/api/api_client.dart';

class MovieWrappedProvider extends ChangeNotifier {
  MovieWrappedProvider({
    required this.userId,
  });

  final String userId;

  MovieWrapped? wrapped;
  bool isLoading = false;
  String? error;

  Future<void> loadYear(int year) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      wrapped = await UserService.getMovieWrapped(userId, year);
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
