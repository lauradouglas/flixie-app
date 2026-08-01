import 'package:flixie_app/models/profile_avatar.dart';

class MovieFriendActivity {
  final String userId;
  final String username;
  final String? firstName;
  final Map<String, dynamic>? iconColor;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;
  final bool onWatchlist;
  final bool watched;
  final bool favorited;
  final int? rating;
  final bool reviewed;
  final bool? reviewRecommended;
  final bool? recommended;
  final int activityScore;
  final String? createdAt;
  final int? watchCount;
  final bool isRewatch;

  const MovieFriendActivity({
    required this.userId,
    required this.username,
    this.firstName,
    this.iconColor,
    this.avatar,
    this.profileBadges = const [],
    required this.onWatchlist,
    required this.watched,
    required this.favorited,
    this.rating,
    this.reviewed = false,
    this.reviewRecommended,
    this.recommended,
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
      avatar: user['avatar'] is Map<String, dynamic>
          ? ProfileAvatar.fromJson(user['avatar'] as Map<String, dynamic>)
          : null,
      profileBadges: (user['profileBadges'] as List<dynamic>? ?? const [])
          .map((item) => item is Map<String, dynamic> ? item['badge'] : item)
          .whereType<String>()
          .toList(growable: false),
      onWatchlist: json['onWatchlist'] as bool? ?? false,
      watched: json['watched'] as bool? ?? false,
      favorited: json['favorited'] as bool? ?? false,
      rating: _parseInt(json['rating']),
      reviewed: json['reviewed'] == true,
      reviewRecommended:
          (json['review'] as Map<String, dynamic>?)?['recommended'] as bool?,
      recommended: json['recommended'] as bool? ??
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
