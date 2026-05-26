class MovieFriendListEntry {
  final String friendUserId;
  final String friendName;
  final String? friendAvatarUrl;
  final String listId;
  final String listName;
  final int? movieCount;
  final String? visibility;
  final List<String> previewPosterUrls;

  const MovieFriendListEntry({
    required this.friendUserId,
    required this.friendName,
    this.friendAvatarUrl,
    required this.listId,
    required this.listName,
    this.movieCount,
    this.visibility,
    this.previewPosterUrls = const [],
  });

  factory MovieFriendListEntry.fromJson(Map<String, dynamic> json) {
    final user = (json['friend'] ?? json['user']) as Map<String, dynamic>? ?? {};
    final list = json['list'] as Map<String, dynamic>? ?? json;
    return MovieFriendListEntry(
      friendUserId: user['id']?.toString() ?? '',
      friendName: (user['username'] ?? user['firstName'] ?? '').toString(),
      friendAvatarUrl: user['profilePictureUrl']?.toString(),
      listId: list['id']?.toString() ?? '',
      listName: (list['name'] ?? '').toString(),
      movieCount: _parseInt(list['movieCount']),
      visibility: list['visibility']?.toString(),
      previewPosterUrls: _parsePreviewPosterUrls(list),
    );
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
