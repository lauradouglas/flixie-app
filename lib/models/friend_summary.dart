class FriendSummaryRating {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final double rating;

  const FriendSummaryRating({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.rating,
  });

  factory FriendSummaryRating.fromJson(Map<String, dynamic> json) {
    return FriendSummaryRating(
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
    );
  }
}

class FriendSummaryResponse {
  final int friendCount;
  final double? averageRating;
  final int watchedCount;
  final int favouriteCount;
  final int watchlistCount;
  final FriendSummaryRating? highestRating;
  final FriendSummaryRating? lowestRating;

  const FriendSummaryResponse({
    required this.friendCount,
    this.averageRating,
    required this.watchedCount,
    required this.favouriteCount,
    required this.watchlistCount,
    this.highestRating,
    this.lowestRating,
  });

  factory FriendSummaryResponse.fromJson(Map<String, dynamic> json) {
    return FriendSummaryResponse(
      friendCount: (json['friendCount'] as num).toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      watchedCount: (json['watchedCount'] as num).toInt(),
      favouriteCount: (json['favouriteCount'] as num).toInt(),
      watchlistCount: (json['watchlistCount'] as num).toInt(),
      highestRating: json['highestRating'] != null
          ? FriendSummaryRating.fromJson(
              json['highestRating'] as Map<String, dynamic>)
          : null,
      lowestRating: json['lowestRating'] != null
          ? FriendSummaryRating.fromJson(
              json['lowestRating'] as Map<String, dynamic>)
          : null,
    );
  }
}
