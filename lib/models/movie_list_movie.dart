import 'watchlist_movie.dart';

class MovieListMovie {
  final String id;
  final String userId;
  final String listId;
  final int movieId;
  final bool removed;
  final String? createdAt;
  final String? updatedAt;
  final WatchlistMovieDetails? movie;

  const MovieListMovie({
    required this.id,
    required this.userId,
    required this.listId,
    required this.movieId,
    required this.removed,
    this.createdAt,
    this.updatedAt,
    this.movie,
  });

  factory MovieListMovie.fromJson(Map<String, dynamic> json) {
    return MovieListMovie(
      id: json['id'] as String,
      userId: json['userId'] as String,
      listId: json['listId'] as String,
      movieId: _parseInt(json['movieId']) ?? 0,
      removed: json['removed'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      movie: json['movie'] is Map<String, dynamic>
          ? WatchlistMovieDetails.fromJson(json['movie'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'listId': listId,
      'movieId': movieId,
      'removed': removed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (movie != null) 'movie': movie!.toJson(),
    };
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
