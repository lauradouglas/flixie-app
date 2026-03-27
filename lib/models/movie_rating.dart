// Helper functions for parsing
int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.parse(value);
  throw FormatException('Cannot parse int from $value');
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed;
  }
  return null;
}

class MovieRating {
  final String id;
  final String userId;
  final int movieId;
  final int rating;
  final String createdAt;
  final String updatedAt;
  final MovieRatingDetails? movie;

  const MovieRating({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.movie,
  });

  factory MovieRating.fromJson(Map<String, dynamic> json) {
    return MovieRating(
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: _parseInt(json['movieId']),
      rating: _parseInt(json['rating']),
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      movie: json['movie'] != null
          ? MovieRatingDetails.fromJson(json['movie'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'rating': rating,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (movie != null) 'movie': movie!.toJson(),
    };
  }
}

class MovieRatingDetails {
  final int id;
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final double? voteAverage;

  const MovieRatingDetails({
    required this.id,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.voteAverage,
  });

  factory MovieRatingDetails.fromJson(Map<String, dynamic> json) {
    return MovieRatingDetails(
      id: _parseInt(json['id']),
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      releaseDate: json['releaseDate'] as String?,
      voteAverage: _parseDouble(json['voteAverage']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'releaseDate': releaseDate,
      'voteAverage': voteAverage,
    };
  }
}
