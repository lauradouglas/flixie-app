import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/review.dart';

import '../models/user.dart';
import '../models/favorite_movie.dart';
import '../models/watchlist_movie.dart';
import '../models/watched_movie.dart';
import '../models/movie_rating.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

class UserService {
  static Future<User> createUser(Map<String, dynamic> body) async {
    final data = await ApiClient.post('/users', body: body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserById(String id) async {
    final data = await ApiClient.get('/users/$id');
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserByUsername(String username) async {
    final data = await ApiClient.get('/users/username/$username');
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<User>> searchUsers(String query) async {
    final data = await ApiClient.get(
      '/users/search',
      queryParams: {'q': query},
    );
    return (data as List<dynamic>)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<User> getUserByExternalId(String externalId) async {
    apiLogger.d('GET /users/external-id/$externalId');
    try {
      final data = await ApiClient.get('/users/external-id/$externalId');
      apiLogger.i(
          'User data received: ${(data as Map<String, dynamic>)['username']}');
      return User.fromJson(data);
    } catch (e) {
      apiLogger.e('Error fetching user by externalId: $e');
      rethrow;
    }
  }

  static Future<bool> usernameExists(String username) async {
    final data = await ApiClient.get('/utils/$username/exists');
    return data as bool;
  }

  /// Updates a single field on the user via POST /users/:userId
  static Future<User> updateUserField(
      String userId, String field, dynamic value) async {
    final data = await ApiClient.post(
      '/users/$userId',
      body: {field: value},
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> updateUser(Map<String, dynamic> body) async {
    final data = await ApiClient.put('/users/update', body: body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> updateEmail(Map<String, dynamic> body) async {
    final data = await ApiClient.put('/users/update/email', body: body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteUser(String externalId) async {
    await ApiClient.delete('/users/external-id/$externalId');
  }

  static Future<List<ActivityListItem>> getUserActivity(String userId) async {
    final data = await ApiClient.get('/users/$userId/activity');
    return (data as List<dynamic>)
        .map((e) => ActivityListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<User> updateIconColor(String userId, int iconColorId) async {
    final data = await ApiClient.post(
      '/users/$userId/icon-color',
      body: {'colorId': iconColorId},
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> addFavoriteGenres(
      String userId, List<int> genreIds) async {
    await ApiClient.post(
      '/users/$userId/genres/favorites',
      body: {'genreIds': genreIds},
    );
  }

  static Future<List<Review>> getMovieReviews(int movieId) async {
    final data = await ApiClient.get('/users/movie/$movieId/reviews');
    return (data as List<dynamic>)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- Movie List Management -----------------------------------------------

  static Future<WatchlistMovie> addToWatchlist(
      String userId, int movieId) async {
    apiLogger.d('POST /users/$userId/movie/watchlist/$movieId');
    final data = await ApiClient.post(
      '/users/$userId/movie/watchlist/$movieId',
      body: {},
    );

    if (data == null) {
      throw Exception('API returned null response');
    }
    return WatchlistMovie.fromJson(data as Map<String, dynamic>);
  }

  static Future<WatchlistMovie> removeFromWatchlist(
      String userId, int movieId) async {
    apiLogger.d('DELETE /users/$userId/movie/watchlist/$movieId');
    final data =
        await ApiClient.delete('/users/$userId/movie/watchlist/$movieId');

    if (data == null) {
      throw Exception('API returned null response');
    }
    return WatchlistMovie.fromJson(data as Map<String, dynamic>);
  }

  static Future<WatchedMovie?> addToWatched(String userId, int movieId) async {
    apiLogger.d('POST /users/$userId/movie/watched/$movieId');
    final data = await ApiClient.post(
      '/users/$userId/movie/watched/$movieId',
      body: {},
    );

    if (data == null) {
      apiLogger.w('API returned null response for addToWatched');
      return null;
    }
    return WatchedMovie.fromJson(data as Map<String, dynamic>);
  }

  static Future<WatchedMovie?> removeFromWatched(
      String userId, int movieId) async {
    apiLogger.d('DELETE /users/$userId/movie/watched/$movieId');
    final data =
        await ApiClient.delete('/users/$userId/movie/watched/$movieId');

    if (data == null) {
      apiLogger.w('API returned null response for removeFromWatched');
      return null;
    }
    return WatchedMovie.fromJson(data as Map<String, dynamic>);
  }

  static Future<FavoriteMovie> addToFavorites(
      String userId, int movieId) async {
    apiLogger.d('POST /users/$userId/movie/favorite/$movieId');
    final data = await ApiClient.post(
      '/users/$userId/movie/favorite/$movieId',
      body: {},
    );

    if (data == null) {
      throw Exception('API returned null response');
    }
    return FavoriteMovie.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> removeFromFavorites(String userId, int movieId) async {
    apiLogger.d('DELETE /users/$userId/movie/favorite/$movieId');
    final data =
        await ApiClient.delete('/users/$userId/movie/favorite/$movieId');
    apiLogger.d('Response type: ${data.runtimeType}');
    // API returns the updated favorites list, not a single object
    // We don't need to parse it since we update locally in the UI
  }

  // ---- Reviews -------------------------------------------------------------

  static Future<List<Review>> getUserMovieReviews(String userId) async {
    apiLogger.d('GET /users/$userId/movies/reviews');
    final data = await ApiClient.get('/users/$userId/movies/reviews');
    return (data as List<dynamic>)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Review> voteOnReview({
    required String mediaType,
    required String mediaId,
    required String reviewId,
    required String voteType,
  }) async {
    assert(voteType == 'upvote' || voteType == 'downvote');
    final data = await ApiClient.post(
      '/users/$mediaType/$mediaId/review/$reviewId/vote',
      body: {'voteType': voteType},
    );
    return Review.fromJson(data as Map<String, dynamic>);
  }

  /// Adds or removes an emoji reaction on a review.
  /// Pass [reactionType] as null to remove the current reaction.
  /// Returns the updated reactions map and the user's current reaction.
  static Future<({Map<String, int> reactions, String? myReaction})>
      reactToReview({
    required String mediaType,
    required String mediaId,
    required String reviewId,
    required String userId,
    required String? reactionType,
  }) async {
    final data = await ApiClient.post(
      '/users/$mediaType/$mediaId/review/$reviewId/react',
      body: {'userId': userId, 'reactionType': reactionType},
    ) as Map<String, dynamic>;
    final reactions = (data['reactions'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
        {};
    return (reactions: reactions, myReaction: data['myReaction'] as String?);
  }

  static Future<Review> addMovieReview(Review review) async {
    apiLogger.d('POST /users/add/MOVIE/review');
    final data = await ApiClient.post(
      '/users/add/MOVIE/review',
      body: {
        'review': {
          'id': review.movieId,
          'userId': review.userId,
          'mediaId': review.movieId,
          'title': review.title,
          'body': review.body,
          'rating': review.rating,
          'recommended': review.recommended,
          'language': review.language,
          'containsSpoilers': review.containsSpoilers,
          'upvotes': 0,
          'downvotes': 0,
        }
      },
    );
    return Review.fromJson(data as Map<String, dynamic>);
  }

  // ---- Ratings -------------------------------------------------------------

  static Future<List<MovieRating>> getUserMovieRatings(String userId) async {
    apiLogger.d('GET /users/$userId/movies/ratings');
    try {
      final data = await ApiClient.get('/users/$userId/movies/ratings');
      final ratings = (data as List<dynamic>)
          .map((e) => MovieRating.fromJson(e as Map<String, dynamic>))
          .toList();
      apiLogger.i('[Ratings] Parsed ${ratings.length} ratings');
      return ratings;
    } catch (e) {
      apiLogger.e('[Ratings] Error fetching ratings: $e');
      rethrow;
    }
  }

  // ---- Watchlist -------------------------------------------------------------

  static Future<List<WatchlistMovie>> getUserWatchlist(String userId) async {
    apiLogger.d('GET /users/$userId/movies/watchlist');
    try {
      final data = await ApiClient.get('/users/$userId/movies/watchlist');
      final watchlist = (data as List<dynamic>)
          .map((e) => WatchlistMovie.fromJson(e as Map<String, dynamic>))
          .toList();
      apiLogger.i('[Watchlist] Parsed ${watchlist.length} items');
      return watchlist;
    } catch (e) {
      apiLogger.e('[Watchlist] Error fetching watchlist: $e');
      rethrow;
    }
  }
}
