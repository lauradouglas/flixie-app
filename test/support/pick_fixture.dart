import 'dart:async';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_short.dart';

/// Fictional accounts and deterministic films; never calls a real API.
class FixturePickService extends PickForUsService {
  String? venue, friendId, groupId, watching, mood;
  bool? openToRent, allowRewatches;
  int? minutes;
  int calls = 0;
  Set<int> excluded = {};
  Set<String> avoided = {};
  List<int> genres = [];
  bool fail = false,
      peopleFail = false,
      empty = false,
      ignoreExclusions = false;
  Completer<FriendsData>? pendingFriends;
  Completer<PickForUsResponse>? pendingPick;
  @override
  Future<FriendsData> friends(String id) async {
    if (pendingFriends != null) return pendingFriends!.future;
    if (peopleFail) throw Exception('offline');
    return const FriendsData(friendships: [
      Friendship(
          id: 'fixture-edge',
          friend: FriendshipUser(
              id: 'fixture-robin',
              username: 'Robin',
              initials: 'R',
              profileBadges: ['FOUNDER']),
          createdAt: '',
          updatedAt: '')
    ], pendingFriends: [], requestedFriends: []);
  }

  @override
  Future<List<Group>> groups(String id) async => [
        Group.fromJson({
          'id': 'fixture-group',
          'name': 'Friday Film Club',
          'ownerId': 'fixture-casey'
        })
      ];
  @override
  Future<PickForUsResponse> pick(
      {String? friendId,
      String? groupId,
      String request = '',
      bool allowRewatches = false,
      Set<String> avoid = const {},
      Set<int> excludeMovieIds = const {},
      List<int> genreIds = const [],
      bool includePossible = true,
      bool includeUnknownContent = false,
      required int maxMinutes,
      required String mood,
      required String venue,
      required String watching,
      required bool openToRent}) async {
    calls++;
    this.friendId = friendId;
    this.groupId = groupId;
    this.mood = mood;
    this.venue = venue;
    this.watching = watching;
    this.openToRent = openToRent;
    this.allowRewatches = allowRewatches;
    minutes = maxMinutes;
    excluded = Set.of(excludeMovieIds);
    avoided = Set.of(avoid);
    genres = List.of(genreIds);
    if (pendingPick != null) return pendingPick!.future;
    if (fail) throw Exception('offline');
    if (empty) {
      return const PickForUsResponse([], 'No matches in this fixture.');
    }
    final films = {
      348: 'Alien',
      571: 'The Birds',
      539: 'Psycho',
      807: 'Se7en',
      1949: 'Zodiac',
      762: 'Monty Python and the Holy Grail'
    };
    return PickForUsResponse(
        films.entries
            .where((f) => ignoreExclusions || !excludeMovieIds.contains(f.key))
            .take(3)
            .map((f) => PickForUsResult(
                MovieShort(
                    id: f.key,
                    name: f.value,
                    overview:
                        'A fictional recommendation fixture for testing the journey.',
                    recommendationReasons: [
                      'On your watchlist',
                      'Fits your time',
                      'Fixture availability on your saved service'
                    ]),
                110))
            .toList(),
        null);
  }
}
