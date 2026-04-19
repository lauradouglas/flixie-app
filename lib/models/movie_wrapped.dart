class MovieWrapped {
  final int year;
  final int totalMoviesWatched;
  final int rewatchCount;
  final double totalHoursWatched;
  final List<WrappedNamedCount> topGenres;
  final List<WrappedNamedCount> topDirectors;
  final List<WrappedTopMovie> topMovies;
  final List<WrappedMonthlyCount> monthlyWatchCounts;

  const MovieWrapped({
    required this.year,
    required this.totalMoviesWatched,
    required this.rewatchCount,
    required this.totalHoursWatched,
    required this.topGenres,
    required this.topDirectors,
    required this.topMovies,
    required this.monthlyWatchCounts,
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

    return MovieWrapped(
      year: _parseInt(json['year']) ?? DateTime.now().year,
      totalMoviesWatched: _parseInt(
              totals?['totalMoviesWatched'] ?? json['totalMoviesWatched']) ??
          0,
      rewatchCount: _parseInt(totals?['rewatchCount'] ?? json['rewatchCount']) ??
          0,
      totalHoursWatched: _parseDouble(
              totals?['totalHoursWatched'] ?? json['totalHoursWatched']) ??
          0,
      topGenres: _namedCounts(json['topGenres']),
      topDirectors: _namedCounts(json['topDirectors']),
      topMovies: (json['topMovies'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WrappedTopMovie.fromJson)
          .toList(),
      monthlyWatchCounts: monthly,
    );
  }
}

class WrappedNamedCount {
  final String name;
  final int count;

  const WrappedNamedCount({required this.name, required this.count});

  factory WrappedNamedCount.fromJson(Map<String, dynamic> json) {
    return WrappedNamedCount(
      name: json['name'] as String? ?? '',
      count: _parseInt(json['count']) ?? 0,
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
      count: _parseInt(json['count']) ?? 0,
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
