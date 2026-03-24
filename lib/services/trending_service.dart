import '../models/movie.dart';
import '../models/show.dart';
import 'api_client.dart';

class TrendingService {
  static Future<List<Movie>> getTrendingMovies(
      {String timeWindow = 'week'}) async {
    final data = await ApiClient.get('/trending/movies',
        queryParams: {'timeWindow': timeWindow});
    return (data as List<dynamic>)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TvShow>> getTrendingShows(
      {String timeWindow = 'week'}) async {
    final data = await ApiClient.get('/trending/shows',
        queryParams: {'timeWindow': timeWindow});
    return (data as List<dynamic>)
        .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
