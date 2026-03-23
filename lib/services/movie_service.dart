import '../models/movie.dart';
import '../models/review.dart';
import 'api_client.dart';

class MovieService {
  static Future<Movie> getMovieById(int id) async {
    final data = await ApiClient.get('/movies/$id');
    return Movie.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<Movie>> getMoviesByIds(List<int> ids) async {
    final data = await ApiClient.post('/movies/by-ids', body: {'ids': ids});
    return (data as List<dynamic>)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addMovieRating(
      int movieId, Map<String, dynamic> body) async {
    await ApiClient.post('/movies/$movieId/ratings', body: body);
  }

  static Future<void> addToWatchlist(String userId, int movieId) async {
    await ApiClient.post(
      '/movies/watchlist',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<void> removeFromWatchlist(String userId, int movieId) async {
    await ApiClient.delete(
      '/movies/watchlist',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<void> addToFavourites(String userId, int movieId) async {
    await ApiClient.post(
      '/movies/favourites',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<void> removeFromFavourites(String userId, int movieId) async {
    await ApiClient.delete(
      '/movies/favourites',
      body: {'userId': userId, 'movieId': movieId},
    );
  }

  static Future<List<Review>> getMovieReviews(int movieId) async {
    final data = await ApiClient.get('/movies/$movieId/reviews');
    return (data as List<dynamic>)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
