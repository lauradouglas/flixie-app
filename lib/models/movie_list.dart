class MovieList {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final String visibility;
  final String? coverImageUrl;
  final String whoCanAddMovies;
  final List<String> previewPosterUrls;
  final bool removed;
  final int? movieCount;
  final String? createdAt;
  final String? updatedAt;

  const MovieList({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.visibility = ListVisibility.private,
    this.coverImageUrl,
    this.whoCanAddMovies = 'owner',
    this.previewPosterUrls = const [],
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
      description: json['description'] as String?,
      visibility: _parseVisibility(json['visibility']?.toString()),
      coverImageUrl: json['coverImageUrl']?.toString(),
      whoCanAddMovies: (json['whoCanAddMovies']?.toString().trim().isNotEmpty ??
              false)
          ? json['whoCanAddMovies'].toString()
          : 'owner',
      previewPosterUrls: _parsePreviewPosterUrls(json),
      removed: json['removed'] as bool? ?? false,
      movieCount: _parseInt(json['movieCount']),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'visibility': visibility,
      'coverImageUrl': coverImageUrl,
      'whoCanAddMovies': whoCanAddMovies,
      'previewPosterUrls': previewPosterUrls,
      'removed': removed,
      'movieCount': movieCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class CreateMovieListRequest {
  final String name;
  final String? description;
  final String visibility;
  final String? coverImageUrl;
  final String whoCanAddMovies;

  const CreateMovieListRequest({
    required this.name,
    this.description,
    this.visibility = ListVisibility.private,
    this.coverImageUrl,
    this.whoCanAddMovies = 'owner',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null && description!.trim().isNotEmpty)
          'description': description,
        'visibility': visibility,
        if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty)
          'coverImageUrl': coverImageUrl,
        'whoCanAddMovies': whoCanAddMovies,
      };
}

class UpdateMovieListRequest {
  final String? name;
  final String? description;
  final String? visibility;
  final String? coverImageUrl;
  final String? whoCanAddMovies;

  const UpdateMovieListRequest({
    this.name,
    this.description,
    this.visibility,
    this.coverImageUrl,
    this.whoCanAddMovies,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (visibility != null) 'visibility': visibility,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (whoCanAddMovies != null) 'whoCanAddMovies': whoCanAddMovies,
      };
}

class ListVisibility {
  static const String private = 'PRIVATE';
  static const String friends = 'FRIENDS';
  static const String public = 'PUBLIC';
}

String _parseVisibility(String? value) {
  final normalized = value?.toUpperCase().trim();
  switch (normalized) {
    case ListVisibility.public:
      return ListVisibility.public;
    case ListVisibility.friends:
      return ListVisibility.friends;
    default:
      return ListVisibility.private;
  }
}

List<String> _parsePreviewPosterUrls(Map<String, dynamic> json) {
  final dynamic raw = json['previewPosterUrls'] ?? json['previewPosters'];
  if (raw is! List) return const [];
  return raw
      .map((entry) => entry?.toString() ?? '')
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
