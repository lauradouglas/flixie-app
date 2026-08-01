import 'package:flixie_app/models/profile_avatar.dart';

class FriendMediaInteraction {
  const FriendMediaInteraction({
    required this.userId,
    required this.username,
    required this.onWatchlist,
    required this.favourited,
    this.avatar,
    this.profileBadges = const [],
  });

  final String userId;
  final String username;
  final bool onWatchlist;
  final bool favourited;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;

  factory FriendMediaInteraction.fromJson(Map<String, dynamic> json) {
    return FriendMediaInteraction(
      userId: (json['friendId'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      onWatchlist: json['watchlist'] == true,
      favourited: json['favorite'] == true,
      avatar: json['avatar'] is Map<String, dynamic>
          ? ProfileAvatar.fromJson(json['avatar'] as Map<String, dynamic>)
          : null,
      profileBadges: (json['profileBadges'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}
