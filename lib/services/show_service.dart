import '../models/show.dart';
import '../models/review.dart';
import '../models/watch_provider.dart';
import 'api_client.dart';

class ShowService {
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

  static Future<void> addShowRating(
      int showId, Map<String, dynamic> body) async {
    await ApiClient.post('/shows/$showId/add/rating', body: body);
  }

  static Future<void> addToWatchlist(String userId, int showId) async {
    await ApiClient.post(
      '/shows/watchlist',
      body: {'userId': userId, 'showId': showId},
    );
  }

  static Future<void> removeFromWatchlist(String userId, int showId) async {
    await ApiClient.delete(
      '/shows/watchlist',
      body: {'userId': userId, 'showId': showId},
    );
  }

  static Future<void> addToFavourites(String userId, int showId) async {
    await ApiClient.post(
      '/shows/favourites',
      body: {'userId': userId, 'showId': showId},
    );
  }

  static Future<void> removeFromFavourites(String userId, int showId) async {
    await ApiClient.delete(
      '/shows/favourites',
      body: {'userId': userId, 'showId': showId},
    );
  }

  static Future<List<Review>> getShowReviews(int showId) async {
    final data = await ApiClient.get('/shows/$showId/reviews');
    return (data as List<dynamic>)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<WatchProvider>> getShowWatchProviders(
    int showId,
    String region,
  ) async {
    List<WatchProvider> parseProviders(dynamic data) {
      return (data as List<dynamic>)
          .map((e) => WatchProvider.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final data = await ApiClient.get('/shows/$showId/$region/watch/providers');
    return parseProviders(data);
  }
}
