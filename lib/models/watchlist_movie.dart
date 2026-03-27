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
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: _parseInt(json['movieId']),
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

  const WatchlistMovieDetails({
    required this.id,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.voteAverage,
    this.runtime,
  });

  factory WatchlistMovieDetails.fromJson(Map<String, dynamic> json) {
    return WatchlistMovieDetails(
      id: _parseInt(json['id']),
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      releaseDate: json['releaseDate'] as String?,
      voteAverage: _parseDouble(json['voteAverage']),
      runtime: _parseInt(json['runtime']),
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
    };
  }
}

// Helper functions
int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.parse(value);
  throw FormatException('Cannot parse int from $value');
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
