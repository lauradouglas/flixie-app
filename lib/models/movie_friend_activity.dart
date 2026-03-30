class MovieFriendActivity {
  final String userId;
  final String username;
  final String? firstName;
  final Map<String, dynamic>? iconColor;
  final bool onWatchlist;
  final bool watched;
  final bool favorited;
  final int? rating;

  const MovieFriendActivity({
    required this.userId,
    required this.username,
    this.firstName,
    this.iconColor,
    required this.onWatchlist,
    required this.watched,
    required this.favorited,
    this.rating,
  });

  factory MovieFriendActivity.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return MovieFriendActivity(
      userId: user['id'] as String,
      username: user['username'] as String,
      firstName: user['firstName'] as String?,
      iconColor: user['iconColor'] as Map<String, dynamic>?,
      onWatchlist: json['onWatchlist'] as bool? ?? false,
      watched: json['watched'] as bool? ?? false,
      favorited: json['favorited'] as bool? ?? false,
      rating: json['rating'] as int?,
    );
  }
}
