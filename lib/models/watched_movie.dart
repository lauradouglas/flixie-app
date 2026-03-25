class WatchedMovie {
  final String id;
  final String userId;
  final int movieId;
  final bool? removed;
  final String? watchedAt;
  final String? createdAt;
  final String? updatedAt;

  const WatchedMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    this.removed,
    this.watchedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory WatchedMovie.fromJson(Map<String, dynamic> json) {
    return WatchedMovie(
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: json['movieId'] as int,
      removed: json['removed'] as bool?,
      watchedAt: json['watchedAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'removed': removed,
      'watchedAt': watchedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
