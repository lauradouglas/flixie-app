class MovieWrapped {
  final int year;
  final int totalMoviesWatched;
  final int rewatchCount;
  final double totalHoursWatched;
  final List<WrappedNamedCount> topGenres;
  final List<WrappedNamedCount> topDirectors;
  final List<WrappedTopMovie> topMovies;
  final List<WrappedRatedMovie> highestRatedMovies;
  final List<WrappedMonthlyCount> monthlyWatchCounts;
  final WrappedCard? wrappedCard;

  const MovieWrapped({
    required this.year,
    required this.totalMoviesWatched,
    required this.rewatchCount,
    required this.totalHoursWatched,
    required this.topGenres,
    required this.topDirectors,
    required this.topMovies,
    required this.highestRatedMovies,
    required this.monthlyWatchCounts,
    this.wrappedCard,
  });

  factory MovieWrapped.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>?;
    final monthly = (json['monthlyWatchCounts'] as List<dynamic>? ??
            json['monthlyCounts'] as List<dynamic>? ??
            const [])
        .whereType<Map<String, dynamic>>()
        .map(WrappedMonthlyCount.fromJson)
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    final cardJson = json['wrappedCard'] as Map<String, dynamic>?;

    return MovieWrapped(
      year: _parseInt(json['year']) ?? DateTime.now().year,
      totalMoviesWatched: _parseInt(
              totals?['totalMoviesWatched'] ?? json['totalMoviesWatched']) ??
          0,
      rewatchCount: _parseInt(totals?['totalWatchCount'] ??
              json['totalWatchCount'] ??
              totals?['rewatchCount'] ??
              json['rewatchCount']) ??
          0,
      totalHoursWatched: _parseDouble(totals?['totalEstimatedWatchHours'] ??
              json['totalEstimatedWatchHours'] ??
              totals?['totalHoursWatched'] ??
              json['totalHoursWatched']) ??
          0,
      topGenres: _namedCounts(json['topGenres']),
      topDirectors: _namedCounts(json['topDirectors']),
      topMovies: (json['mostRewatchedMovies'] as List<dynamic>? ??
              json['topMovies'] as List<dynamic>? ??
              const [])
          .whereType<Map<String, dynamic>>()
          .map(WrappedTopMovie.fromJson)
          .toList(),
      highestRatedMovies:
          (json['highestRatedMovies'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(WrappedRatedMovie.fromJson)
              .toList(),
      monthlyWatchCounts: monthly,
      wrappedCard: cardJson != null ? WrappedCard.fromJson(cardJson) : null,
    );
  }
}

class WrappedCard {
  final int year;
  final int totalWatchCount;
  final WrappedNamedCount? topGenre;
  final WrappedTopMovie? mostRewatchedMovie;
  final WrappedNamedCount? topDirector;

  const WrappedCard({
    required this.year,
    required this.totalWatchCount,
    this.topGenre,
    this.mostRewatchedMovie,
    this.topDirector,
  });

  factory WrappedCard.fromJson(Map<String, dynamic> json) {
    final rewatchJson = json['mostRewatchedMovie'] as Map<String, dynamic>?;
    final genreJson = json['topGenre'] as Map<String, dynamic>?;
    final directorJson = json['topDirector'] as Map<String, dynamic>?;
    return WrappedCard(
      year: _parseInt(json['year']) ?? DateTime.now().year,
      totalWatchCount: _parseInt(json['totalWatchCount']) ?? 0,
      topGenre:
          genreJson != null ? WrappedNamedCount.fromJson(genreJson) : null,
      mostRewatchedMovie:
          rewatchJson != null ? WrappedTopMovie.fromJson(rewatchJson) : null,
      topDirector: directorJson != null
          ? WrappedNamedCount.fromJson(directorJson)
          : null,
    );
  }
}

class WrappedRatedMovie {
  final int movieId;
  final String title;
  final String? posterPath;
  final int rating;

  const WrappedRatedMovie({
    required this.movieId,
    required this.title,
    this.posterPath,
    required this.rating,
  });

  factory WrappedRatedMovie.fromJson(Map<String, dynamic> json) {
    return WrappedRatedMovie(
      movieId: _parseInt(json['movieId'] ?? json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      posterPath: json['posterPath'] as String?,
      rating: _parseInt(json['rating']) ?? 0,
    );
  }
}

class WrappedNamedCount {
  final String name;
  final int count;
  final int? personId;

  const WrappedNamedCount(
      {required this.name, required this.count, this.personId});

  factory WrappedNamedCount.fromJson(Map<String, dynamic> json) {
    return WrappedNamedCount(
      name: json['name'] as String? ?? '',
      count: _parseInt(json['watchCount'] ?? json['count']) ?? 0,
      personId: _parseInt(json['id'] ?? json['personId']),
    );
  }
}

class WrappedTopMovie {
  final int movieId;
  final String title;
  final String? posterPath;
  final int watchCount;

  const WrappedTopMovie({
    required this.movieId,
    required this.title,
    this.posterPath,
    required this.watchCount,
  });

  factory WrappedTopMovie.fromJson(Map<String, dynamic> json) {
    return WrappedTopMovie(
      movieId: _parseInt(json['movieId'] ?? json['id']) ?? 0,
      title: json['title'] as String? ?? '',
      posterPath: json['posterPath'] as String?,
      watchCount: _parseInt(json['watchCount'] ?? json['count']) ?? 0,
    );
  }
}

class WrappedMonthlyCount {
  final int month;
  final int count;

  const WrappedMonthlyCount({
    required this.month,
    required this.count,
  });

  factory WrappedMonthlyCount.fromJson(Map<String, dynamic> json) {
    return WrappedMonthlyCount(
      month: _parseInt(json['month']) ?? 0,
      count: _parseInt(json['watchCount'] ?? json['count']) ?? 0,
    );
  }
}

List<WrappedNamedCount> _namedCounts(dynamic raw) {
  return (raw as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(WrappedNamedCount.fromJson)
      .toList();
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
