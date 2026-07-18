import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/models/search_result.dart';
import 'package:flixie_app/core/api/api_client.dart';

class SearchService {
  // static Future<SearchResults> search(
  //   String value, {
  //   String type = 'all',
  //   int page = 1,
  // }) async {
  //   final data = await ApiClient.get('/search', queryParams: {
  //     'value': value,
  //     'type': type,
  //     'page': page.toString(),
  //   });
  //   return SearchResults.fromJson(data as Map<String, dynamic>);
  // }

  static Future<SearchResults> search(
    String value, {
    String type = 'all',
    int page = 1,
  }) async {
    final data = await ApiClient.get('/search', queryParams: {
      'value': value,
      'type': type,
      'page': page.toString(),
    });

    final results = SearchResults.fromJson(data as Map<String, dynamic>);
    if (type != 'all') return results;

    final shows = await searchShows(value).catchError((_) => <TvShow>[]);
    if (shows.isEmpty) return results;

    final existingShowIds = results.results
        .where((item) => item.isShow)
        .map((item) => item.show?.id)
        .whereType<int>()
        .toSet();
    final additionalShows = shows
        .where((show) => !existingShowIds.contains(show.id))
        .map(SearchResultItem.fromShow);
    final merged = [...results.results, ...additionalShows];

    return SearchResults(
      page: results.page,
      results: merged,
      totalPages: results.totalPages,
      totalResults: merged.length,
    );
  }

  static Future<SearchEntityResults> searchCompany(
    String value, {
    int page = 1,
  }) async {
    final data = await ApiClient.get('/search/company', queryParams: {
      'value': value,
      'page': page.toString(),
    });
    return SearchEntityResults.fromJson(
      data as Map<String, dynamic>,
      type: SearchEntityType.company,
    );
  }

  static Future<SearchEntityResults> searchCollection(
    String value, {
    int page = 1,
  }) async {
    final data = await ApiClient.get('/search/collection', queryParams: {
      'value': value,
      'page': page.toString(),
    });
    return SearchEntityResults.fromJson(
      data as Map<String, dynamic>,
      type: SearchEntityType.collection,
    );
  }

  static Future<List<Movie>> searchMovies(String query) async {
    final data =
        await ApiClient.get('/search/movies', queryParams: {'query': query});
    return (data as List<dynamic>)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<TvShow>> searchShows(String query) async {
    final data = await ApiClient.get('/search', queryParams: {
      'value': query,
      'type': 'tv',
      'page': '1',
    });
    final results = SearchResults.fromJson(data as Map<String, dynamic>);
    return results.results
        .where((item) => item.isShow && item.show != null)
        .map((item) => item.show!)
        .toList();
  }

  static Future<List<Person>> searchPeople(String query) async {
    final data =
        await ApiClient.get('/search/people', queryParams: {'query': query});
    return (data as List<dynamic>)
        .map((e) => Person.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> searchAll(String query) async {
    final data = await ApiClient.get('/search', queryParams: {'query': query});
    return data as Map<String, dynamic>;
  }
}
