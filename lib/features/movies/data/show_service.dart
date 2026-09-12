import 'package:flixie_app/features/movies/data/media_review_service.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';

class ShowService {
  static Future<List<ContinueWatchingShow>> getContinueWatching(
    String userId, {
    int limit = 10,
  }) async {
    final data = await ApiClient.get(
      '/users/$userId/shows/continue-watching',
      queryParams: {'limit': '$limit'},
    );
    return (data as List<dynamic>)
        .map((item) => ContinueWatchingShow.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  static Future<void> dismissContinueWatching(
    String userId,
    int showId,
  ) async {
    await ApiClient.delete('/users/$userId/shows/$showId/continue-watching');
  }

  static Future<TvShow> getShowById(int id, {String? userId}) async {
    final data = await ApiClient.get(
      '/shows/id/$id',
      queryParams: userId == null ? null : {'userId': userId},
    );
    return TvShow.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> updateEpisodeProgress({
    required String userId,
    required int showId,
    required int episodeId,
    required bool watched,
    String? watchedAt,
    int? rating,
  }) async {
    await ApiClient.patch(
      '/users/$userId/shows/$showId/episodes/$episodeId/progress',
      body: {
        'watched': watched,
        if (watchedAt != null) 'watchedAt': watchedAt,
        if (rating != null) 'rating': rating,
      },
    );
  }

  static Future<void> updateSeasonProgress({
    required String userId,
    required int showId,
    required int seasonNumber,
    required bool watched,
    String? watchedAt,
  }) async {
    await ApiClient.patch(
      '/users/$userId/shows/$showId/seasons/$seasonNumber/progress',
      body: {
        'watched': watched,
        if (watchedAt != null) 'watchedAt': watchedAt,
      },
    );
  }

  static Future<List<TvShow>> getShowsByIds(List<int> ids) async {
    final data = await ApiClient.post('/shows/by-ids', body: {'ids': ids});
    return (data as List<dynamic>)
        .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TvShowCredits> getShowCredits(int showId) async {
    final data = await ApiClient.get('/shows/$showId/credits');
    if (data is List<dynamic>) {
      return TvShowCredits(
        cast: data
            .whereType<Map<String, dynamic>>()
            .map(TvShowCredit.fromJson)
            .toList(growable: false),
      );
    }
    return TvShowCredits.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> addShowRating(
      int showId, String userId, int rating) async {
    final data = await ApiClient.post(
      '/shows/$showId/add/rating',
      body: {'userId': userId, 'rating': rating},
    );
    return data as Map<String, dynamic>;
  }

  static Future<int?> getUserShowRating(int showId, String userId) async {
    try {
      final data = await ApiClient.post(
        '/shows/$showId/user/rating',
        body: {'userId': userId},
      );
      if (data is Map<String, dynamic>) {
        final rating = data['rating'];
        if (rating is num) return rating.toInt();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> addToWatchlist(String userId, int showId) async {
    await ApiClient.post('/users/$userId/show/watchlist/$showId');
  }

  static Future<void> removeFromWatchlist(String userId, int showId) async {
    await ApiClient.delete('/users/$userId/show/watchlist/$showId');
  }

  static Future<Map<String, dynamic>> addToFavourites(
      String userId, int showId) async {
    final data = await ApiClient.post('/users/$userId/show/favorite/$showId');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> removeFromFavourites(String userId, int showId) async {
    await ApiClient.delete('/users/$userId/show/favorite/$showId');
  }

  static Future<List<Review>> getShowReviews(int showId, {String? userId}) =>
      MediaReviewService.getReviews(ReviewMediaType.show, showId,
          userId: userId);

  static Future<Map<int, FriendRecommendationResponse>>
      getFriendRecommendations(Iterable<int> showIds,
          {bool Function()? isCurrent}) async {
    final ids = showIds.where((id) => id > 0).toSet().toList();
    final results = <int, FriendRecommendationResponse>{};
    for (var start = 0; start < ids.length; start += 25) {
      if (isCurrent != null && !isCurrent()) break;
      final chunk = ids.skip(start).take(25).toList();
      try {
        final data = await ApiClient.post('/shows/friend-recommendations',
            body: {'showIds': chunk});
        for (final item in data['items'] as List) {
          try {
            final id =
                int.parse((item['showId'] ?? item['movieId']).toString());
            if (chunk.contains(id)) {
              results[id] = FriendRecommendationResponse.fromJson(
                  Map<String, dynamic>.from(item as Map));
            }
          } catch (_) {
            /* Keep valid titles in a partially malformed response. */
          }
        }
      } catch (error) {
        if (error is ApiException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          rethrow;
        }
      }
    }
    return results;
  }

  static final _providerCache =
      <String, ({DateTime fetchedAt, List<WatchProvider> providers})>{};

  static Future<TvShowFriendSummary?> getFriendSummary(int showId) async {
    final data = await ApiClient.get('/shows/$showId/friend-summary');
    return data is Map<String, dynamic>
        ? TvShowFriendSummary.fromJson(data)
        : null;
  }

  static Future<List<WatchProvider>> getShowWatchProviders(
    int showId,
    String region,
  ) async {
    final cacheKey = '$region:$showId';
    final cached = _providerCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(hours: 1)) {
      return cached.providers;
    }

    final data = await ApiClient.get('/shows/$showId/$region/watch/providers');
    final providers = parseWatchProviderOffers(data);
    if (_providerCache.length >= 256) {
      _providerCache.remove(_providerCache.keys.first);
    }
    _providerCache[cacheKey] =
        (fetchedAt: DateTime.now(), providers: providers);
    return providers;
  }
}
