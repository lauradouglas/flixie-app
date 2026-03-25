class WatchlistMovie {
  final String id;
  final String userId;
  final int movieId;
  final bool? removed;
  final String? createdAt;
  final String? updatedAt;

  const WatchlistMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    this.removed,
    this.createdAt,
    this.updatedAt,
  });

  factory WatchlistMovie.fromJson(Map<String, dynamic> json) {
    return WatchlistMovie(
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: json['movieId'] as int,
      removed: json['removed'] as bool?,
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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
