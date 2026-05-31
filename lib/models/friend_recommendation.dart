class FriendRecommendationItem {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final double? rating;
  final bool recommends;
  final bool watched;
  final String? reviewSnippet;

  const FriendRecommendationItem({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.rating,
    required this.recommends,
    this.watched = true,
    this.reviewSnippet,
  });

  factory FriendRecommendationItem.fromJson(Map<String, dynamic> json) {
    final rating = (json['rating'] as num?)?.toDouble();
    // Fall back to inferring watched from rating presence if the backend
    // does not send the field explicitly.
    final watched = json['watched'] as bool? ?? rating != null;
    return FriendRecommendationItem(
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      rating: rating,
      recommends: json['recommends'] as bool? ?? false,
      watched: watched,
      reviewSnippet: json['reviewSnippet'] as String?,
    );
  }
}

class FriendRecommendationResponse {
  final int recommendPercent;
  final int friendCount;
  final int recommendedCount;
  final double? averageFriendRating;
  final List<FriendRecommendationItem> friends;

  const FriendRecommendationResponse({
    required this.recommendPercent,
    required this.friendCount,
    required this.recommendedCount,
    this.averageFriendRating,
    required this.friends,
  });

  factory FriendRecommendationResponse.fromJson(Map<String, dynamic> json) {
    return FriendRecommendationResponse(
      recommendPercent: (json['recommendPercent'] as num).toInt(),
      friendCount: (json['friendCount'] as num).toInt(),
      recommendedCount: (json['recommendedCount'] as num).toInt(),
      averageFriendRating: (json['averageFriendRating'] as num?)?.toDouble(),
      friends: (json['friends'] as List<dynamic>? ?? [])
          .map((e) =>
              FriendRecommendationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
