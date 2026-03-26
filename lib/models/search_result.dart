import 'movie_short.dart';
import 'person.dart';

class SearchResultItem {
  final bool isPerson;
  final MovieShort? movie;
  final Person? person;

  const SearchResultItem._({
    required this.isPerson,
    this.movie,
    this.person,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String?;
    if (mediaType == 'person') {
      return SearchResultItem._(isPerson: true, person: Person.fromJson(json));
    }
    return SearchResultItem._(
        isPerson: false, movie: MovieShort.fromJson(json));
  }
}

class SearchResults {
  final int page;
  final List<SearchResultItem> results;
  final int totalPages;
  final int totalResults;

  const SearchResults({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    return SearchResults(
      page: (json['page'] as num?)?.toInt() ?? 1,
      results: resultsList
          .map((e) => SearchResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      totalResults: (json['totalResults'] as num?)?.toInt() ?? 0,
    );
  }
}
