class WatchlistMovie {
  final String id;
  final String userId;
  final int movieId;
  final bool? removed;
  final String? createdAt;
  final String? updatedAt;
  final WatchlistMovieDetails? movie;

  const WatchlistMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    this.removed,
    this.createdAt,
    this.updatedAt,
    this.movie,
  });

  factory WatchlistMovie.fromJson(Map<String, dynamic> json) {
    return WatchlistMovie(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      movieId: _parseInt(json['movieId']) ?? 0,
      removed: json['removed'] as bool?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      movie: json['movie'] != null
          ? WatchlistMovieDetails.fromJson(
              json['movie'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'removed': removed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (movie != null) 'movie': movie!.toJson(),
    };
  }
}

class WatchlistMovieDetails {
  final int id;
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final double? voteAverage;
  final int? runtime;
  final List<String> genres;

  const WatchlistMovieDetails({
    required this.id,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.voteAverage,
    this.runtime,
    this.genres = const [],
  });

  factory WatchlistMovieDetails.fromJson(Map<String, dynamic> json) {
    return WatchlistMovieDetails(
      id: _parseInt(json['id']) ?? 0,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      releaseDate: json['releaseDate'] as String?,
      voteAverage: _parseDouble(json['voteAverage']),
      runtime: _parseInt(json['runtime']),
      genres: json['genres'] != null
          ? (json['genres'] as List<dynamic>)
              .map((g) => g is Map<String, dynamic>
                  ? (g['name'] as String? ?? '')
                  : g.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'releaseDate': releaseDate,
      'voteAverage': voteAverage,
      'runtime': runtime,
      'genres': genres,
    };
  }
}

// Helper functions
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
