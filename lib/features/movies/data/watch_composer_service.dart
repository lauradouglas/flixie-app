import 'package:flixie_app/models/movie_short.dart';
import 'search_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'movie_service.dart';

/// Existing API operations used by one invitation composer; no shared cache.
class WatchComposerService {
  const WatchComposerService();
  Future<List<Friendship>> friends(String id) async =>
      (await FriendService.getFriends(id)).friendships;
  Future<List<Group>> groups(String id) => GroupService.getUserGroups(id);
  Future<List<GroupMember>> members(String id) =>
      GroupService.getGroupMembers(id);
  Future<List<WatchProvider>> userProviders(String id) =>
      UserService.getUserWatchProviders(id);
  Future<List<WatchProvider>> movieProviders(int id, String region) =>
      MovieService().getMovieWatchProviders(id, region);
  Future<List<MovieShort>> searchMovies(String query) async =>
      (await SearchService.search(query, type: 'movie'))
          .results
          .map((r) => r.movie)
          .whereType<MovieShort>()
          .toList();
  Future<List<MovieShort>> cinemaMovies(String region) =>
      MovieService().getNowPlayingMovies(region: region);
  Future<String?> send(
      {required String userId,
      required String recipientId,
      required bool group,
      required List<int> movies,
      required String message,
      String? proposedDate,
      required bool dateOnly,
      String? location}) async {
    final Map<String, dynamic>? result;
    if (group) {
      result = await GroupService.sendWatchRequest(
          recipientId, userId, message, 'MOVIE', movies.first,
          candidateMovieIds: movies,
          proposedDate: proposedDate,
          proposedDateOnly: dateOnly,
          location: location);
      final request = result?['watchRequest'] as Map<String, dynamic>?;
      return (request?['pgGroupRequestId'] ?? request?['id'])?.toString();
    }
    result = await RequestService.sendRequest({
      'requesterId': userId,
      'recipientId': recipientId,
      'movieId': movies.first,
      'candidateMovieIds': movies,
      'message': message,
      'type': 'MOVIE_WATCH_REQUEST',
      if (proposedDate != null) 'proposedDate': proposedDate,
      'proposedDateOnly': dateOnly,
      if (location != null) 'location': location,
    });
    return (result?['request'] as Map<String, dynamic>?)?['id']?.toString();
  }
}
