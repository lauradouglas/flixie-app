enum ActivityListType {
  movieWatchlist('watchlist-movie'),
  showWatchlist('watchlist-show'),
  movieWatched('watched-movie'),
  showWatched('watched-show'),
  favoriteMovie('favorite-movie'),
  favoriteShow('favorite-show'),
  favoritePerson('favorite-person'),
  movieRating('movie-rating'),
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
  final String? mediaPosterPath;
  final double? mediaRating;

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
    this.mediaPosterPath,
    this.mediaRating,
  });

  factory ActivityListItem.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final show = json['show'] as Map<String, dynamic>?;
    final person = json['person'] as Map<String, dynamic>?;
    final review = json['review'] as Map<String, dynamic>?;
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
      mediaTitle: movie?['title'] as String? ??
          show?['title'] as String? ??
          person?['name'] as String?,
      mediaPosterPath: movie?['posterPath'] as String? ??
          show?['posterPath'] as String? ??
          person?['profileImgUrl'] as String?,
      mediaRating: (json['rating'] as num?)?.toDouble() ??
          (review?['rating'] as num?)?.toDouble(),
    );
  }
}
