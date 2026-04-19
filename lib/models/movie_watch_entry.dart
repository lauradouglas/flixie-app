import 'watchlist_movie.dart';

class MovieWatchEntry {
  final String id;
  final String userId;
  final int movieId;
  final String? watchedAt;
  final double? rating;
  final String? notes;
  final bool removed;
  final String? createdAt;
  final String? updatedAt;
  final WatchlistMovieDetails? movie;

  const MovieWatchEntry({
    required this.id,
    required this.userId,
    required this.movieId,
    this.watchedAt,
    this.rating,
    this.notes,
    required this.removed,
    this.createdAt,
    this.updatedAt,
    this.movie,
  });

  factory MovieWatchEntry.fromJson(Map<String, dynamic> json) {
    return MovieWatchEntry(
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: _parseInt(json['movieId']) ?? 0,
      watchedAt: json['watchedAt'] as String? ?? json['createdAt'] as String?,
      rating: _parseDouble(json['rating']),
      notes: json['notes'] as String?,
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
      'movieId': movieId,
      'watchedAt': watchedAt,
      'rating': rating,
      'notes': notes,
      'removed': removed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (movie != null) 'movie': movie!.toJson(),
    };
  }
}

class LogMovieWatchRequest {
  final int movieId;
  final String? watchedAt;
  final double? rating;
  final String? notes;

  const LogMovieWatchRequest({
    required this.movieId,
    this.watchedAt,
    this.rating,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'movieId': movieId,
      if (watchedAt != null) 'watchedAt': watchedAt,
      'rating': rating,
      'notes': notes,
    };
  }
}

class UpdateMovieWatchRequest {
  final double? rating;
  final String? notes;
  final String? watchedAt;

  const UpdateMovieWatchRequest({
    this.rating,
    this.notes,
    this.watchedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'notes': notes,
      if (watchedAt != null) 'watchedAt': watchedAt,
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

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
