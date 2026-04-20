class WatchedMovie {
  final String id;
  final String userId;
  final int movieId;
  final bool? removed;
  final String? watchedAt;
  final double? rating;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? movie;

  const WatchedMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    this.removed,
    this.watchedAt,
    this.rating,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.movie,
  });

  factory WatchedMovie.fromJson(Map<String, dynamic> json) {
    return WatchedMovie(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      movieId: _parseInt(json['movieId']) ?? 0,
      removed: json['removed'] as bool?,
      watchedAt: json['watchedAt'] as String?,
      rating: _parseDouble(json['rating']),
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      movie: json['movie'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'removed': removed,
      'watchedAt': watchedAt,
      'rating': rating,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'movie': movie,
    };
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
