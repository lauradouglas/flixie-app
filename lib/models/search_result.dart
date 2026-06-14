import 'movie_short.dart';
import 'person.dart';
import 'show.dart';

class SearchResultItem {
  final bool isPerson;
  final bool isShow;
  final MovieShort? movie;
  final TvShow? show;
  final Person? person;

  const SearchResultItem._({
    required this.isPerson,
    required this.isShow,
    this.movie,
    this.show,
    this.person,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    final mediaType =
        _stringValue(json['mediaType'] ?? json['media_type'])?.toLowerCase();
    if (mediaType == 'person') {
      return SearchResultItem._(
        isPerson: true,
        isShow: false,
        person: Person.fromJson(json),
      );
    }
    if (mediaType == 'tv' || mediaType == 'show') {
      return SearchResultItem.fromShow(TvShow.fromJson(json));
    }
    return SearchResultItem._(
      isPerson: false,
      isShow: false,
      movie: MovieShort.fromJson(json),
    );
  }

  factory SearchResultItem.fromShow(TvShow show) {
    return SearchResultItem._(
      isPerson: false,
      isShow: true,
      show: show,
    );
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

enum SearchEntityType {
  company,
  collection,
}

SearchEntityType _entityTypeFromMediaType(
  String? mediaType,
  SearchEntityType fallback,
) {
  return switch (mediaType) {
    'company' => SearchEntityType.company,
    'collection' => SearchEntityType.collection,
    _ => fallback,
  };
}

String? _stringValue(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  return str.isEmpty ? null : str;
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class SearchEntityResult {
  const SearchEntityResult({
    required this.id,
    required this.name,
    required this.type,
    required this.mediaType,
    this.posterPath,
    this.backdropPath,
    this.logoPath,
    this.originCountry,
    this.overview,
  });

  final int id;
  final String name;
  final SearchEntityType type;
  final String mediaType;
  final String? posterPath;
  final String? backdropPath;
  final String? logoPath;
  final String? originCountry;
  final String? overview;

  factory SearchEntityResult.fromJson(
    Map<String, dynamic> json, {
    required SearchEntityType type,
  }) {
    final mediaType = _stringValue(json['mediaType'] ?? json['media_type']);
    final resolvedType = _entityTypeFromMediaType(mediaType, type);

    return SearchEntityResult(
      id: _intValue(json['id']),
      name: _stringValue(json['name']) ?? _stringValue(json['title']) ?? '',
      type: resolvedType,
      mediaType: mediaType ?? resolvedType.name,
      posterPath: _stringValue(json['posterPath'] ?? json['poster_path']),
      backdropPath: _stringValue(json['backdropPath'] ?? json['backdrop_path']),
      logoPath: _stringValue(json['logoPath'] ?? json['logo_path']),
      originCountry:
          _stringValue(json['originCountry'] ?? json['origin_country']),
      overview: _stringValue(json['overview']),
    );
  }
}

class SearchEntityResults {
  const SearchEntityResults({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  final int page;
  final List<SearchEntityResult> results;
  final int totalPages;
  final int totalResults;

  factory SearchEntityResults.fromJson(
    Map<String, dynamic> json, {
    required SearchEntityType type,
  }) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    final parsedResults = resultsList
        .map((e) => SearchEntityResult.fromJson(
              e as Map<String, dynamic>,
              type: type,
            ))
        .where((result) => result.name.isNotEmpty)
        .toList();

    return SearchEntityResults(
      page: _intValue(json['page'], fallback: 1),
      results: parsedResults,
      totalPages: _intValue(json['totalPages'] ?? json['total_pages']),
      totalResults: _intValue(
        json['totalResults'] ?? json['total_results'],
        fallback: parsedResults.length,
      ),
    );
  }
}
