class MovieList {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final String visibility;
  final String scope;
  final String? groupId;
  final String? groupName;
  final List<MovieListCollaborator> collaborators;
  final bool canEdit;
  final bool isOwner;
  final String? coverImageUrl;
  final String whoCanAddMovies;
  final List<String> previewPosterUrls;
  final bool removed;
  final int? itemCount;
  final int? movieCount;
  final int? showCount;
  final String? createdAt;
  final String? updatedAt;

  const MovieList({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.visibility = ListVisibility.private,
    this.scope = ListScope.personal,
    this.groupId,
    this.groupName,
    this.collaborators = const [],
    this.canEdit = true,
    this.isOwner = true,
    this.coverImageUrl,
    this.whoCanAddMovies = 'owner',
    this.previewPosterUrls = const [],
    required this.removed,
    this.itemCount,
    this.movieCount,
    this.showCount,
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
      scope: (json['scope'] ?? ListScope.personal).toString().toUpperCase(),
      groupId: json['groupId']?.toString(),
      groupName: (json['group'] as Map<String, dynamic>?)?['name']?.toString(),
      collaborators: (json['collaborators'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MovieListCollaborator.fromJson)
          .toList(growable: false),
      canEdit: json['canEdit'] as bool? ?? true,
      isOwner: json['isOwner'] as bool? ?? true,
      coverImageUrl: json['coverImageUrl']?.toString(),
      whoCanAddMovies:
          (json['whoCanAddMovies']?.toString().trim().isNotEmpty ?? false)
              ? json['whoCanAddMovies'].toString()
              : (json['whoCanAddItems']?.toString().trim().isNotEmpty ?? false)
                  ? json['whoCanAddItems'].toString()
                  : 'owner',
      previewPosterUrls: _parsePreviewPosterUrls(json),
      removed: json['removed'] as bool? ?? false,
      itemCount: _parseInt(json['itemCount']),
      movieCount: _parseInt(json['movieCount']),
      showCount: _parseInt(json['showCount']),
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
      'scope': scope,
      'groupId': groupId,
      'groupName': groupName,
      'collaborators': collaborators.map((entry) => entry.toJson()).toList(),
      'canEdit': canEdit,
      'isOwner': isOwner,
      'coverImageUrl': coverImageUrl,
      'whoCanAddMovies': whoCanAddMovies,
      'previewPosterUrls': previewPosterUrls,
      'removed': removed,
      'itemCount': itemCount,
      'movieCount': movieCount,
      'showCount': showCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class CreateMovieListRequest {
  final String name;
  final List<int>? movieIds;
  final List<int>? showIds;
  final String? description;
  final String visibility;
  final String? coverImageUrl;
  final String whoCanAddMovies;
  final String scope;
  final String? groupId;
  final List<String> collaboratorIds;

  const CreateMovieListRequest({
    required this.name,
    this.movieIds,
    this.showIds,
    this.description,
    this.visibility = ListVisibility.private,
    this.coverImageUrl,
    this.whoCanAddMovies = 'owner',
    this.scope = ListScope.personal,
    this.groupId,
    this.collaboratorIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (movieIds != null && movieIds!.isNotEmpty) 'movieIds': movieIds,
        if (showIds != null && showIds!.isNotEmpty) 'showIds': showIds,
        if (description != null && description!.trim().isNotEmpty)
          'description': description,
        'visibility': visibility,
        if (coverImageUrl != null && coverImageUrl!.trim().isNotEmpty)
          'coverImageUrl': coverImageUrl,
        'whoCanAddItems': whoCanAddMovies,
        'scope': scope,
        if (groupId != null) 'groupId': groupId,
        if (collaboratorIds.isNotEmpty) 'collaboratorIds': collaboratorIds,
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
        if (whoCanAddMovies != null) 'whoCanAddItems': whoCanAddMovies,
      };
}

class ListVisibility {
  static const String private = 'PRIVATE';
  static const String friends = 'FRIENDS';
  static const String public = 'PUBLIC';
}

class ListScope {
  static const String personal = 'PERSONAL';
  static const String friends = 'FRIENDS';
  static const String group = 'GROUP';
}

class MovieListCollaborator {
  const MovieListCollaborator({
    required this.id,
    required this.username,
  });

  final String id;
  final String username;

  factory MovieListCollaborator.fromJson(Map<String, dynamic> json) =>
      MovieListCollaborator(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
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
