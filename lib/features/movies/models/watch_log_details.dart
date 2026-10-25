import 'package:flixie_app/models/friendship.dart';

/// Extra fields owned by the watch editor; persistence stays with its caller.
class WatchLogDetails {
  const WatchLogDetails(
      {this.companion,
      this.watchedAtCinema = false,
      this.companions = const [],
      this.externalCompanionName,
      this.reviewBody = '',
      this.containsSpoilers = false});
  final bool watchedAtCinema;
  final FriendshipUser? companion;
  final List<FriendshipUser> companions;
  final String? externalCompanionName;
  final String reviewBody;
  final bool containsSpoilers;
}
