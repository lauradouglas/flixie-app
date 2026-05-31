class MovieFriendActivity {
  final String userId;
  final String username;
  final String? firstName;
  final Map<String, dynamic>? iconColor;
  final bool onWatchlist;
  final bool watched;
  final bool favorited;
  final int? rating;
  final bool? reviewRecommended;
  final int activityScore;
  final String? createdAt;
  final int? watchCount;
  final bool isRewatch;

  const MovieFriendActivity({
    required this.userId,
    required this.username,
    this.firstName,
    this.iconColor,
    required this.onWatchlist,
    required this.watched,
    required this.favorited,
    this.rating,
    this.reviewRecommended,
    this.activityScore = 0,
    this.createdAt,
    this.watchCount,
    this.isRewatch = false,
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
      rating: _parseInt(json['rating']),
      reviewRecommended:
          (json['review'] as Map<String, dynamic>?)?['recommended'] as bool?,
      activityScore: _parseInt(json['activityScore']) ?? 0,
      createdAt: (json['createdAt'] ?? json['updatedAt']) as String?,
      watchCount: _parseInt(json['watchCount'] ?? json['totalWatchCount']),
      isRewatch: json['isRewatch'] == true ||
          json['rewatch'] == true ||
          ((_parseInt(json['watchCount'] ?? json['totalWatchCount']) ?? 0) > 1),
    );
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
