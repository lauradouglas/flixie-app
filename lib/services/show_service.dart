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

  static Future<void> addToFavourites(String userId, int showId) async {
    await ApiClient.post('/users/$userId/show/favorite/$showId');
  }

  static Future<void> removeFromFavourites(String userId, int showId) async {
    await ApiClient.delete('/users/$userId/show/favorite/$showId');
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
      Iterable<dynamic> typedList(String type, dynamic value) {
        if (value is! Iterable) return const [];
        return value.whereType<Map<String, dynamic>>().map(
              (provider) => {
                ...provider,
                'availabilityType': type,
              },
            );
      }

      final source = data is Map<String, dynamic>
          ? [
              ...typedList('stream', data['stream'] ?? data['flatrate']),
              ...typedList('buy', data['buy']),
              ...typedList('rent', data['rent']),
              ...typedList('stream', data['providers']),
              ...typedList('stream', data['results']),
              ...typedList('stream', data['streaming']),
              ...typedList('stream', data['watchProviders']),
            ]
          : (data as List<dynamic>? ?? const []);
      return source
          .map((e) => WatchProvider.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final data = await ApiClient.get('/shows/$showId/$region/watch/providers');
    return parseProviders(data);
  }
}
