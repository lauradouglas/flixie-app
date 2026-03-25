class FavoriteMovie {
  final String id;
  final String userId;
  final int movieId;
  final int? rank;
  final bool? removed;
  final String? createdAt;
  final String? updatedAt;

  const FavoriteMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    this.rank,
    this.removed,
    this.createdAt,
    this.updatedAt,
  });

  factory FavoriteMovie.fromJson(Map<String, dynamic> json) {
    return FavoriteMovie(
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: json['movieId'] as int,
      rank: json['rank'] as int?,
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
      'rank': rank,
      'removed': removed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
