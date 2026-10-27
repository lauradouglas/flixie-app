import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'user_service.dart';

class DiaryEntryService {
  const DiaryEntryService();

  Future<List<MovieShort>> search(String query) async {
    final result = await SearchService.search(query, type: 'movie');
    return result.results
        .where((r) => r.movie != null && !r.isPerson)
        .map((r) => r.movie!)
        .toList();
  }

  Future<List<Friendship>> friends(String userId) async =>
      (await FriendService.getFriends(userId)).friendships;

  Future<MovieWatchEntry> log(String userId, LogMovieWatchRequest request) =>
      UserService.logMovieWatch(userId, request);

  Future<MovieWatchEntry> update(
          String userId, String entryId, UpdateMovieWatchRequest request) =>
      UserService.updateMovieWatch(userId, entryId, request);
}
