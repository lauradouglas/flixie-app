import '../models/movie.dart';
import '../models/show.dart';
import '../models/person.dart';
import '../models/search_result.dart';
import 'api_client.dart';

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
    if (_isShowSearchType(type)) {
      final shows = await searchShows(value);
      return _showResults(shows, page: page);
    }

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
    final data =
        await ApiClient.get('/search/shows', queryParams: {'query': query});
    return (data as List<dynamic>)
        .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
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

  static bool _isShowSearchType(String type) {
    final normalized = type.toLowerCase();
    return normalized == 'tv' || normalized == 'show' || normalized == 'shows';
  }

  static SearchResults _showResults(List<TvShow> shows, {required int page}) {
    return SearchResults(
      page: page,
      results: shows.map(SearchResultItem.fromShow).toList(),
      totalPages: 1,
      totalResults: shows.length,
    );
  }
}
