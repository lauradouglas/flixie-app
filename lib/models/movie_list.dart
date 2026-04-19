class MovieList {
  final String id;
  final String? userId;
  final String name;
  final bool removed;
  final int? movieCount;
  final String? createdAt;
  final String? updatedAt;

  const MovieList({
    required this.id,
    this.userId,
    required this.name,
    required this.removed,
    this.movieCount,
    this.createdAt,
    this.updatedAt,
  });

  factory MovieList.fromJson(Map<String, dynamic> json) {
    return MovieList(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString(),
      name: json['name'] as String? ?? '',
      removed: json['removed'] as bool? ?? false,
      movieCount: json['movieCount'] as int?,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'removed': removed,
      'movieCount': movieCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class CreateMovieListRequest {
  final String name;

  const CreateMovieListRequest({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}

class UpdateMovieListRequest {
  final String name;

  const UpdateMovieListRequest({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}
