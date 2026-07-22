import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/show_list.dart';
import 'package:flixie_app/models/show_watch_entry.dart';
import 'package:flixie_app/models/watch_provider.dart';

import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/activity_feed_ranking.dart';
import 'package:flixie_app/core/api/api_client.dart';

class UserService {
  static const List<String> _movieWatchlistSuffixCandidates = [
    '/movie/watchlist',
  ];
  static String? _resolvedMovieWatchlistSuffix;

  static Future<T> _withMovieWatchlistBasePath<T>(
    String userId,
    Future<T> Function(String basePath) action,
  ) async {
    final suffixes = <String>[
      if (_resolvedMovieWatchlistSuffix != null) _resolvedMovieWatchlistSuffix!,
      ..._movieWatchlistSuffixCandidates
          .where((s) => s != _resolvedMovieWatchlistSuffix),
    ];

    ApiException? last404;
    for (final suffix in suffixes) {
      final basePath = '/users/$userId$suffix';
      try {
        final result = await action(basePath);
        _resolvedMovieWatchlistSuffix = suffix;
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          last404 = e;
          continue;
        }
        rethrow;
      }
    }

    throw last404 ??
        const ApiException(
          statusCode: 404,
          message: 'Movie watchlist endpoint not found for this backend.',
        );
  }

  static const List<String> _movieListSuffixCandidates = [
    '/lists',
  ];
  static String? _resolvedMovieListSuffix;

  static Future<T> _withMovieListsBasePath<T>(
    String userId,
    Future<T> Function(String basePath) action,
  ) async {
    final suffixes = <String>[
      if (_resolvedMovieListSuffix != null) _resolvedMovieListSuffix!,
      ..._movieListSuffixCandidates.where((s) => s != _resolvedMovieListSuffix),
    ];

    ApiException? last404;
    for (final suffix in suffixes) {
      final basePath = '/users/$userId$suffix';
      try {
        final result = await action(basePath);
        _resolvedMovieListSuffix = suffix;
        return result;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          last404 = e;
          continue;
        }
        rethrow;
      }
    }

    throw last404 ??
        const ApiException(
          statusCode: 404,
          message: 'Movie lists endpoint not found for this backend.',
        );
  }

  static Future<User> createUser(Map<String, dynamic> body) async {
    final profileBody = <String, dynamic>{
      'firstName': body['firstName'],
      'lastName': body['lastName'],
      'username': body['username'],
      'email': body['email'],
      'bio': body['bio'] ?? '',
      'countryId': body['countryId'],
      'languageId': body['languageId'],
    };
    final data = await ApiClient.post('/users/', body: profileBody);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserById(String id) async {
    final data = await ApiClient.get('/users/$id');
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserByUsername(String username) async {
    final encodedUsername = Uri.encodeComponent(username);
    final data = await ApiClient.get('/users/username/$encodedUsername');
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
    final data = await ApiClient.get(
      usernameAvailabilityPath(username),
      authenticated: false,
    );
    return data as bool;
  }

  static String usernameAvailabilityPath(String username) =>
      '/users/${Uri.encodeComponent(username)}/exists';

  /// Updates a single field on the user via PUT /users/:userId.
  static Future<User> updateUserField(
      String userId, String field, dynamic value) async {
    final data = await ApiClient.put(
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
    final activities = (data as List<dynamic>)
        .map((e) => ActivityListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return rankActivitiesForFeed(activities);
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
    final data = await _withMovieWatchlistBasePath(
      userId,
      (basePath) => ApiClient.post(
        '$basePath/$movieId',
        body: {},
      ),
    );

    if (data == null) {
      throw Exception('API returned null response');
    }
    return WatchlistMovie.fromJson(data as Map<String, dynamic>);
  }

  static Future<WatchlistMovie> removeFromWatchlist(
      String userId, int movieId) async {
    final data = await _withMovieWatchlistBasePath(
      userId,
      (basePath) => ApiClient.delete('$basePath/$movieId'),
    );

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

  static Future<List<WatchedMovie>> getUserWatchedMovies(String userId) async {
    apiLogger.d('GET /users/$userId/movies/watched');
    final data = await ApiClient.get('/users/$userId/movies/watched');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(WatchedMovie.fromJson)
        .where((item) => item.removed != true)
        .toList();
  }

  static Future<WatchedMovie?> getLatestMovieWatched(
      String userId, int movieId) async {
    apiLogger.d('GET /users/$userId/movie/$movieId/watched');
    final data = await ApiClient.get('/users/$userId/movie/$movieId/watched');
    if (data == null) return null;
    if (data is! Map<String, dynamic>) return null;
    return WatchedMovie.fromJson(data);
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

  /// Adds a group of movies to favourites through the backend's bulk route.
  /// The bulk route imports any missing TMDB movies before creating the user
  /// relationships, which is important for onboarding search results.
  static Future<void> addMoviesToFavorites(
      String userId, Iterable<int> movieIds) async {
    final ids = movieIds.toSet().toList(growable: false);
    if (ids.isEmpty) return;
    await ApiClient.post(
      '/users/$userId/movies/favorites',
      body: {'movieIds': ids},
    );
  }

  /// Adds a group of watched movies, importing missing TMDB movies first on
  /// the backend before watch entries are created.
  static Future<void> addMoviesToWatched(
      String userId, Iterable<int> movieIds) async {
    final ids = movieIds.toSet().toList(growable: false);
    if (ids.isEmpty) return;
    await ApiClient.post(
      '/users/$userId/movies/watched',
      body: {'movieIds': ids},
    );
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

  // ---- FCM Token Management ------------------------------------------------

  /// Saves (or updates) the FCM device token for push notifications.
  static Future<void> saveFcmToken(String userId, String token) async {
    await ApiClient.post(
      '/users/$userId/fcm-token',
      body: {'token': token},
    );
  }

  /// Removes the stored FCM device token (call on sign-out).
  static Future<void> removeFcmToken(String userId) async {
    await ApiClient.delete('/users/$userId/fcm-token');
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
    try {
      final data = await ApiClient.get('/users/$userId/watchlists');
      final rawWatchlist = data is Map<String, dynamic>
          ? data['movieWatchlistWithWatchedStatus'] ??
              data['movieWatchlist'] ??
              const <dynamic>[]
          : data;
      final watchlist = (rawWatchlist as List<dynamic>)
          .map((e) => WatchlistMovie.fromJson(e as Map<String, dynamic>))
          .toList();
      apiLogger.i('[Watchlist] Parsed ${watchlist.length} items');
      return watchlist;
    } catch (e) {
      apiLogger.e('[Watchlist] Error fetching watchlist: $e');
      rethrow;
    }
  }

  // ---- Mixed Lists (movies and shows) ---------------------------------------

  static Future<List<MovieList>> getMovieLists(String userId) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.get(basePath),
    );
    final lists = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MovieList.fromJson)
        .where((list) => !list.removed)
        .toList()
      ..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
    return lists;
  }

  static Future<MovieList> createMovieList(
    String userId,
    CreateMovieListRequest request,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.post(
        basePath,
        body: request.toJson(),
      ),
    );
    return MovieList.fromJson(data as Map<String, dynamic>);
  }

  static Future<MovieList> renameMovieList(
    String userId,
    String listId,
    UpdateMovieListRequest request,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.patch(
        '$basePath/$listId',
        body: request.toJson(),
      ),
    );
    return MovieList.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteMovieList(String userId, String listId) async {
    await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.delete('$basePath/$listId'),
    );
  }

  static Future<List<MovieListMovie>> getMovieListMovies(
    String userId,
    String listId,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.get('$basePath/$listId/items'),
    );
    final moviesList = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ??
            data['movies'] as List<dynamic>? ??
            []
        : data as List<dynamic>? ?? [];
    final movies = moviesList
        .whereType<Map<String, dynamic>>()
        .map(MovieListMovie.fromJson)
        .where((entry) => !entry.removed)
        .toList()
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return movies;
  }

  static Future<MovieListMovie> addMovieToList(
    String userId,
    String listId,
    int movieId,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.post(
        '$basePath/$listId/movies/$movieId',
        body: {},
      ),
    );
    final raw = data as Map<String, dynamic>;
    final movies = raw['movies'] as List<dynamic>? ??
        (raw['items'] as List<dynamic>? ?? const [])
            .where((item) =>
                item is Map<String, dynamic> && item['movieId'] != null)
            .toList(growable: false);
    final first = movies.whereType<Map<String, dynamic>>().firstOrNull;
    return MovieListMovie.fromJson(first ?? raw);
  }

  static Future<List<MovieListMovie>> addMoviesToList(
    String userId,
    String listId,
    List<int> movieIds,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.post(
        '$basePath/$listId/items',
        body: {'movieIds': movieIds},
      ),
    );
    final raw = data as Map<String, dynamic>;
    final movies = raw['movies'] as List<dynamic>? ??
        (raw['items'] as List<dynamic>? ?? const [])
            .where((item) =>
                item is Map<String, dynamic> && item['movieId'] != null)
            .toList(growable: false);
    return movies
        .whereType<Map<String, dynamic>>()
        .map(MovieListMovie.fromJson)
        .toList(growable: false);
  }

  static Future<void> removeMovieFromList(
    String userId,
    String listId,
    int movieId,
  ) async {
    await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.delete('$basePath/$listId/movies/$movieId'),
    );
  }

  static Future<List<MovieList>> getMyListsContainingMovie(
    String userId,
    int movieId,
  ) async {
    final lists = await getMovieLists(userId);
    if (lists.isEmpty) return const <MovieList>[];

    final result = <MovieList>[];
    for (final list in lists) {
      final movies = await getMovieListMovies(userId, list.id);
      if (movies.any((entry) =>
          !entry.removed &&
          (entry.movieId == movieId || entry.movie?.id == movieId))) {
        result.add(list);
      }
    }
    return result;
  }

  // ---- Show list compatibility over mixed lists -----------------------------

  static Future<List<ShowList>> getShowLists(String userId) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.get(basePath),
    );
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ShowList.fromJson)
        .where((list) => !list.removed)
        .toList()
      ..sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
  }

  static Future<ShowList> createShowList(
    String userId,
    CreateShowListRequest request,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.post(
        basePath,
        body: request.toJson(),
      ),
    );
    return ShowList.fromJson(data as Map<String, dynamic>);
  }

  static Future<ShowList> renameShowList(
    String userId,
    String listId,
    UpdateShowListRequest request,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.patch(
        '$basePath/$listId',
        body: request.toJson(),
      ),
    );
    return ShowList.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteShowList(String userId, String listId) async {
    await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.delete('$basePath/$listId'),
    );
  }

  static Future<List<TvShow>> getShowListShows(
    String userId,
    String listId,
  ) async {
    final data = await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.get('$basePath/$listId/items'),
    );
    final source = data is Map<String, dynamic>
        ? data['shows'] as List<dynamic>? ??
            (data['items'] as List<dynamic>? ?? const [])
                .where((item) =>
                    item is Map<String, dynamic> && item['showId'] != null)
                .toList(growable: false)
        : data as List<dynamic>? ?? const [];
    return source.whereType<Map<String, dynamic>>().map((json) {
      final showJson = json['show'] is Map<String, dynamic>
          ? json['show'] as Map<String, dynamic>
          : json;
      return TvShow.fromJson(showJson);
    }).toList(growable: false);
  }

  static Future<void> addShowToList(
    String userId,
    String listId,
    int showId,
  ) async {
    await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.post(
        '$basePath/$listId/shows/$showId',
        body: {},
      ),
    );
  }

  static Future<void> addShowsToList(
    String userId,
    String listId,
    List<int> showIds,
  ) async {
    await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.post(
        '$basePath/$listId/items',
        body: {'showIds': showIds},
      ),
    );
  }

  static Future<void> removeShowFromList(
    String userId,
    String listId,
    int showId,
  ) async {
    await _withMovieListsBasePath(
      userId,
      (basePath) => ApiClient.delete('$basePath/$listId/shows/$showId'),
    );
  }

  static Future<List<MovieFriendListEntry>> getFriendsListsContainingMovie(
    String userId,
    int movieId,
  ) async {
    final data = await ApiClient.get(
      '/movies/id/$movieId/friends-activity',
      queryParams: {'userId': userId},
    );
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MovieFriendListEntry.fromJson)
        .where(
            (entry) => entry.listId.isNotEmpty && entry.friendUserId.isNotEmpty)
        .toList(growable: false);
  }

  // ---- Rewatch / watch entries ----------------------------------------------

  static Future<MovieWatchEntry> logMovieWatch(
    String userId,
    LogMovieWatchRequest request,
  ) async {
    final data = await ApiClient.post(
      '/users/$userId/movie/watches',
      body: request.toJson(),
    );
    return MovieWatchEntry.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<MovieWatchEntry>> getUserMovieWatches(
      String userId) async {
    final data = await ApiClient.get('/users/$userId/movie/watches');
    final watches = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MovieWatchEntry.fromJson)
        .where((entry) => !entry.removed)
        .toList()
      ..sort((a, b) => (b.watchedAt ?? '').compareTo(a.watchedAt ?? ''));
    return watches;
  }

  static Future<List<MovieWatchEntry>> getMovieWatchHistory(
    String userId,
    int movieId,
  ) async {
    final data = await ApiClient.get('/users/$userId/movie/$movieId/watches');
    final watches = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MovieWatchEntry.fromJson)
        .where((entry) => !entry.removed)
        .toList()
      ..sort((a, b) => (b.watchedAt ?? '').compareTo(a.watchedAt ?? ''));
    return watches;
  }

  static Future<MovieWatchEntry> updateMovieWatch(
    String userId,
    String watchEntryId,
    UpdateMovieWatchRequest request,
  ) async {
    final data = await ApiClient.patch(
      '/users/$userId/movie/watches/$watchEntryId',
      body: request.toJson(),
    );
    return MovieWatchEntry.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteMovieWatch(
      String userId, String watchEntryId) async {
    await ApiClient.delete('/users/$userId/movie/watches/$watchEntryId');
  }

  static Future<ShowWatchEntry> logShowWatch(
    String userId,
    LogShowWatchRequest request,
  ) async {
    final data = await ApiClient.post(
      '/users/$userId/show/watches',
      body: request.toJson(),
    );
    return ShowWatchEntry.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<ShowWatchEntry>> getUserShowWatches(String userId) async {
    final data = await ApiClient.get('/users/$userId/show/watches');
    final watches = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ShowWatchEntry.fromJson)
        .where((entry) => !entry.removed)
        .toList()
      ..sort((a, b) => (b.watchedAt ?? '').compareTo(a.watchedAt ?? ''));
    return watches;
  }

  static Future<List<ShowWatchEntry>> getShowWatchHistory(
    String userId,
    int showId,
  ) async {
    final data = await ApiClient.get('/users/$userId/show/$showId/watches');
    final watches = (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ShowWatchEntry.fromJson)
        .where((entry) => !entry.removed)
        .toList()
      ..sort((a, b) => (b.watchedAt ?? '').compareTo(a.watchedAt ?? ''));
    return watches;
  }

  static Future<ShowWatchEntry> updateShowWatch(
    String userId,
    String watchEntryId,
    UpdateShowWatchRequest request,
  ) async {
    final data = await ApiClient.patch(
      '/users/$userId/show/watches/$watchEntryId',
      body: request.toJson(),
    );
    return ShowWatchEntry.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteShowWatch(
      String userId, String watchEntryId) async {
    await ApiClient.delete('/users/$userId/show/watches/$watchEntryId');
  }

  // ---- Wrapped / Year in Review ---------------------------------------------

  static Future<MovieWrapped> getMovieWrapped(String userId, int year) async {
    final data = await ApiClient.get('/users/$userId/movie/wrapped/$year');
    return MovieWrapped.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<WatchProvider>> getUserWatchProviders(
      String userId) async {
    final data = await ApiClient.get('/users/$userId/watch-providers');

    final list = data['watchProviders'] as List<dynamic>;

    return list
        .map((item) => WatchProvider.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateUserWatchProviders(
    String userId,
    List<int> watchProviderIds,
  ) async {
    await ApiClient.put(
      '/users/$userId/watch-providers',
      body: {
        'watchProviderIds': watchProviderIds,
      },
    );
  }
}
