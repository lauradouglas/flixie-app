import '../models/show.dart';
import '../models/review.dart';
import 'api_client.dart';

class ShowService {
  static Future<TvShow> getShowById(int id) async {
    final data = await ApiClient.get('/shows/$id');
    return TvShow.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<TvShow>> getShowsByIds(List<int> ids) async {
    final data = await ApiClient.post('/shows/by-ids', body: {'ids': ids});
    return (data as List<dynamic>)
        .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addShowRating(
      int showId, Map<String, dynamic> body) async {
    await ApiClient.post('/shows/$showId/ratings', body: body);
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
}
