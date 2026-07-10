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
    final fallbackName = json['displayName']?.toString() ?? '';
    return FriendSummaryRating(
      userId: json['userId']?.toString() ?? '',
      username: (json['username'] as String?) ?? fallbackName,
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
  final List<FriendSummaryRating> highestRatings;
  final FriendSummaryRating? lowestRating;
  final List<FriendSummaryRating> lowestRatings;

  const FriendSummaryResponse({
    required this.friendCount,
    this.averageRating,
    required this.watchedCount,
    required this.favouriteCount,
    required this.watchlistCount,
    this.highestRating,
    this.highestRatings = const [],
    this.lowestRating,
    this.lowestRatings = const [],
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
      highestRatings: _ratingList(json['highestRatings']),
      lowestRating: json['lowestRating'] != null
          ? FriendSummaryRating.fromJson(
              json['lowestRating'] as Map<String, dynamic>)
          : null,
      lowestRatings: _ratingList(json['lowestRatings']),
    );
  }
}

List<FriendSummaryRating> _ratingList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(FriendSummaryRating.fromJson)
      .toList(growable: false);
}
