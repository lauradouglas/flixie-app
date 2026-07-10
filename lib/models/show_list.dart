class ShowList {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final String visibility;
  final String? coverImageUrl;
  final String whoCanAddShows;
  final List<String> previewPosterUrls;
  final bool removed;
  final int? itemCount;
  final int? movieCount;
  final int? showCount;
  final String? createdAt;
  final String? updatedAt;

  const ShowList({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.visibility = ShowListVisibility.private,
    this.coverImageUrl,
    this.whoCanAddShows = 'owner',
    this.previewPosterUrls = const [],
    required this.removed,
    this.itemCount,
    this.movieCount,
    this.showCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ShowList.fromJson(Map<String, dynamic> json) {
    return ShowList(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      visibility: _parseVisibility(json['visibility']?.toString()),
      coverImageUrl: json['coverImageUrl']?.toString(),
      whoCanAddShows:
          (json['whoCanAddShows']?.toString().trim().isNotEmpty ?? false)
              ? json['whoCanAddShows'].toString()
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
      'coverImageUrl': coverImageUrl,
      'whoCanAddShows': whoCanAddShows,
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

class CreateShowListRequest {
  final String name;
  final List<int>? movieIds;
  final List<int>? showIds;
  final String? description;
  final String visibility;
  final String? coverImageUrl;
  final String whoCanAddShows;

  const CreateShowListRequest({
    required this.name,
    this.movieIds,
    this.showIds,
    this.description,
    this.visibility = ShowListVisibility.private,
    this.coverImageUrl,
    this.whoCanAddShows = 'owner',
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
        'whoCanAddItems': whoCanAddShows,
      };
}

class UpdateShowListRequest {
  final String? name;
  final String? description;
  final String? visibility;
  final String? coverImageUrl;
  final String? whoCanAddShows;

  const UpdateShowListRequest({
    this.name,
    this.description,
    this.visibility,
    this.coverImageUrl,
    this.whoCanAddShows,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (visibility != null) 'visibility': visibility,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (whoCanAddShows != null) 'whoCanAddItems': whoCanAddShows,
      };
}

class ShowListVisibility {
  static const String private = 'PRIVATE';
  static const String friends = 'FRIENDS';
  static const String public = 'PUBLIC';
}

String _parseVisibility(String? value) {
  final normalized = value?.toUpperCase().trim();
  switch (normalized) {
    case ShowListVisibility.public:
      return ShowListVisibility.public;
    case ShowListVisibility.friends:
      return ShowListVisibility.friends;
    default:
      return ShowListVisibility.private;
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
