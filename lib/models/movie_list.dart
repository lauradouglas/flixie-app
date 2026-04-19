class MovieList {
  final String id;
  final String userId;
  final String name;
  final bool removed;
  final String? createdAt;
  final String? updatedAt;

  const MovieList({
    required this.id,
    required this.userId,
    required this.name,
    required this.removed,
    this.createdAt,
    this.updatedAt,
  });

  factory MovieList.fromJson(Map<String, dynamic> json) {
    return MovieList(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String? ?? '',
      removed: json['removed'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'removed': removed,
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
