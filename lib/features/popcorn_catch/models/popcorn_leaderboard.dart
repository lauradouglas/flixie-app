import 'package:flixie_app/models/profile_avatar.dart';

class PopcornEntry {
  const PopcornEntry(
      {required this.rank,
      required this.score,
      required this.userId,
      required this.username,
      this.avatar,
      this.roundReached = 1,
      this.profileBadges = const []});
  final int rank, score, roundReached;
  final String userId, username;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;
  factory PopcornEntry.fromJson(Map<String, dynamic> json) => PopcornEntry(
        rank: json['rank'] as int,
        roundReached: json['roundReached'] as int? ?? 1,
        score: json['score'] as int,
        userId: json['userId'] as String,
        username: json['username'] as String,
        avatar: json['avatar'] == null
            ? null
            : ProfileAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
        profileBadges: List<String>.from(json['profileBadges'] as List? ?? []),
      );
}

class PopcornLeaderboard {
  const PopcornLeaderboard(
      {this.items = const [], this.personalBest, this.personalRank});
  final List<PopcornEntry> items;
  final int? personalBest, personalRank;
  factory PopcornLeaderboard.fromJson(Map<String, dynamic> json) =>
      PopcornLeaderboard(
        items: (json['items'] as List)
            .map((item) => PopcornEntry.fromJson(item as Map<String, dynamic>))
            .toList(),
        personalBest: json['personalBest'] as int?,
        personalRank: json['personalRank'] as int?,
      );
}

class PopcornRound {
  const PopcornRound(this.id, this.seed,
      {this.personalBest, this.version = 2, this.guestToken, this.expiresAt});
  final int version;
  final String? guestToken;
  final DateTime? expiresAt;
  final int? personalBest;
  final String id;
  final int seed;
}
