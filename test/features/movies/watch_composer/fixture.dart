import 'package:flixie_app/models/movie_short.dart';
import 'dart:async';
import 'package:flixie_app/features/movies/data/watch_composer_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/watch_provider.dart';

class ComposerFixture extends WatchComposerService {
  final searches = <String>[], cinemaRegions = <String>[];
  @override
  Future<List<MovieShort>> searchMovies(String query) async {
    searches.add(query);
    return const [
      MovieShort(id: 348, name: 'Alien'),
      MovieShort(id: 1368337, name: 'The Odyssey')
    ];
  }

  @override
  Future<List<MovieShort>> cinemaMovies(String region) async {
    cinemaRegions.add(region);
    return const [MovieShort(id: 1368337, name: 'The Odyssey')];
  }

  final userReads = <String, int>{}, movieReads = <int, int>{};
  final pendingUsers = <String, Completer<List<WatchProvider>>>{};
  final writes = <Map<String, Object?>>[];
  Completer<String?>? writeGate;
  Completer<List<Friendship>>? friendGate;
  bool failSend = false, failFriends = false, failGroups = false;
  final failUsers = <String>{};
  int friendReads = 0, groupReads = 0, memberReads = 0;
  static List<WatchProvider> offers(int id) => [
        WatchProvider.fromJson({
          'id': id,
          'providerName': 'Fixture TV $id',
          'logoPath': '',
          'availabilityTypes': ['flatrate']
        })
      ];
  @override
  Future<List<Friendship>> friends(String id) async {
    friendReads++;
    if (failFriends) throw StateError('Friends unavailable');
    if (friendGate != null) return friendGate!.future;
    return [
      for (final name in ['Robin', 'Ellis'])
        Friendship(
            id: name,
            createdAt: '',
            updatedAt: '',
            friend: FriendshipUser(
                id: name, username: name, profileBadges: const ['FOUNDER']))
    ];
  }

  @override
  Future<List<Group>> groups(String id) async {
    groupReads++;
    if (failGroups) throw StateError('Groups unavailable');
    return [
      for (final name in ['Film friends', 'Alien fans'])
        Group(id: name, name: name, ownerId: 'viewer')
    ];
  }

  @override
  Future<List<GroupMember>> members(String id) async {
    memberReads++;
    return [
      for (final name in [
        'viewer',
        'Robin',
        if (id == 'Film friends') 'Ellis' else 'Blair'
      ])
        GroupMember(
            groupId: id,
            memberId: name,
            role: name == 'viewer' ? 'OWNER' : 'MEMBER',
            inviteStatus: 'ACCEPTED')
    ];
  }

  @override
  Future<List<WatchProvider>> userProviders(String id) async {
    userReads.update(id, (v) => v + 1, ifAbsent: () => 1);
    if (failUsers.remove(id)) throw StateError('Providers unavailable');
    if (pendingUsers.containsKey(id)) return pendingUsers[id]!.future;
    return offers(id == 'Ellis' ? 2 : 1);
  }

  @override
  Future<List<WatchProvider>> movieProviders(int id, String region) async {
    movieReads.update(id, (v) => v + 1, ifAbsent: () => 1);
    return offers(id == 348 ? 1 : 2);
  }

  @override
  Future<String?> send(
      {required String userId,
      required String recipientId,
      required bool group,
      required List<int> movies,
      required String message,
      String? proposedDate,
      required bool dateOnly,
      String? location}) async {
    if (failSend) {
      failSend = false;
      throw StateError('Save unavailable');
    }
    writes.add({
      'userId': userId,
      'recipientId': recipientId,
      'group': group,
      'movies': movies,
      'message': message,
      'dateOnly': dateOnly,
      'proposedDate': proposedDate,
      'location': location
    });
    if (writeGate != null) return writeGate!.future;
    return 'fixture-plan';
  }
}
