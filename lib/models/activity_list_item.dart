enum ActivityListType {
  movieWatchlist('watchlist-movie'),
  showWatchlist('watchlist-show'),
  movieWatched('watched-movie'),
  showWatched('watched-show'),
  favoriteMovie('favorite-movie'),
  favoriteShow('favorite-show'),
  favoritePerson('favorite-person'),
  watchRequestSent('watch-request-sent'),
  watchRequestAccepted('watch-request-accepted'),
  unknown('unknown');

  const ActivityListType(this.value);
  final String value;

  static ActivityListType fromString(String? raw) {
    for (final t in values) {
      if (t.value == raw) return t;
    }
    return unknown;
  }
}

class ActivityListItem {
  final String id;
  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final int? movieId;
  final int? showId;
  final int? personId;
  final bool removed;
  final String createdAt;
  final String updatedAt;
  final ActivityListType type;
  final String? mediaTitle;

  const ActivityListItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.movieId,
    this.showId,
    this.personId,
    required this.removed,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    this.mediaTitle,
  });

  factory ActivityListItem.fromJson(Map<String, dynamic> json) {
    return ActivityListItem(
      id: json['id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      movieId: json['movieId'] as int?,
      showId: json['showId'] as int?,
      personId: json['personId'] as int?,
      removed: json['removed'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      type: ActivityListType.fromString(json['type'] as String?),
      mediaTitle: (json['movie'] as Map<String, dynamic>?)?['title'] as String?
          ?? (json['show'] as Map<String, dynamic>?)?['title'] as String?
          ?? (json['person'] as Map<String, dynamic>?)?['name'] as String?,
    );
  }
}
