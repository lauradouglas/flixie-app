import 'watchlist_movie.dart';
import 'show.dart';

class MovieListMovie {
  final String id;
  final String userId;
  final String listId;
  final int movieId;
  final int showId;
  final bool removed;
  final String? createdAt;
  final String? updatedAt;
  final WatchlistMovieDetails? movie;
  final TvShow? show;

  const MovieListMovie({
    required this.id,
    required this.userId,
    required this.listId,
    required this.movieId,
    this.showId = 0,
    required this.removed,
    this.createdAt,
    this.updatedAt,
    this.movie,
    this.show,
  });

  factory MovieListMovie.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] is Map<String, dynamic>
        ? WatchlistMovieDetails.fromJson(json['movie'] as Map<String, dynamic>)
        : null;
    final show = json['show'] is Map<String, dynamic>
        ? TvShow.fromJson(json['show'] as Map<String, dynamic>)
        : null;
    return MovieListMovie(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      listId: json['listId']?.toString() ?? '',
      movieId: _parseInt(json['movieId']) ?? movie?.id ?? 0,
      showId: _parseInt(json['showId']) ?? show?.id ?? 0,
      removed: json['removed'] as bool? ?? false,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      movie: movie,
      show: show,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'listId': listId,
      'movieId': movieId,
      'showId': showId,
      'removed': removed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (movie != null) 'movie': movie!.toJson(),
      if (show != null) 'show': show!.toJson(),
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
