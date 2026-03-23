import '../models/movie.dart';
import '../models/show.dart';
import '../models/person.dart';
import 'api_client.dart';

class SearchService {
  static Future<List<Movie>> searchMovies(String query) async {
    final data = await ApiClient.get('/search/movies',
        queryParams: {'query': query});
    return (data as List<dynamic>)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TvShow>> searchShows(String query) async {
    final data = await ApiClient.get('/search/shows',
        queryParams: {'query': query});
    return (data as List<dynamic>)
        .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Person>> searchPeople(String query) async {
    final data = await ApiClient.get('/search/people',
        queryParams: {'query': query});
    return (data as List<dynamic>)
        .map((e) => Person.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> searchAll(String query) async {
    final data =
        await ApiClient.get('/search', queryParams: {'query': query});
    return data as Map<String, dynamic>;
  }
}
