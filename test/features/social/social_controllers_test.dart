import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/controllers/social_people_controller.dart';
import 'package:flixie_app/features/social/presentation/controllers/social_groups_controller.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/social/data/social_groups_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/user.dart';
import '../../support/watchlist_auth.dart';

const empty =
    FriendsData(friendships: [], pendingFriends: [], requestedFriends: []);
const request = Friendship(
    id: 'request',
    friend: FriendshipUser(
        id: 'friend', username: 'Friend', profileBadges: ['EARLY_ADOPTER']),
    createdAt: '',
    updatedAt: '');

class SocialAuth extends TestAuth {
  String viewer = 'viewer';
  FriendsData? friends;
  List<Group>? groups;
  @override
  User get dbUser => User(
      id: viewer,
      username: viewer,
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  FriendsData? get cachedFriends => friends;
  @override
  List<Group>? get cachedGroups => groups;
  @override
  void updateCachedFriends(FriendsData value) {
    friends = value;
  }

  @override
  void updateCachedGroups(List<Group> value) {
    groups = value;
  }
}

class Actions extends FriendActionsController {
  final loads = <Completer<FriendsData>>[];
  final write = Completer<void>();
  int writes = 0;
  bool fail = false;
  @override
  Future<FriendsData> getFriends(String id) {
    final work = Completer<FriendsData>();
    loads.add(work);
    return work.future;
  }

  @override
  Future<void> acceptRequest(String id) async {
    writes++;
    if (fail) throw StateError('offline');
    await write.future;
  }

  @override
  Future<void> declineRequest(String id) => acceptRequest(id);
}

class Groups extends SocialGroupsService {
  final reads = <Completer<SocialGroupsSnapshot>>[];
  @override
  Future<SocialGroupsSnapshot> load(String viewer, {bool Function()? owns}) {
    final work = Completer<SocialGroupsSnapshot>();
    reads.add(work);
    return work.future;
  }
}

SocialGroupsSnapshot snapshot(String name) => SocialGroupsSnapshot(
    confirmed: [Group(id: name, name: name, ownerId: 'viewer')],
    groups: [Group(id: name, name: name, ownerId: 'viewer')],
    pending: {},
    members: {},
    notifications: {});

class Memberships extends SocialGroupsService {
  int active = 0, peak = 0, started = 0;
  final gates = <Completer<void>>[];
  @override
  Future<List<Group>> groups(String viewer) async => List.generate(
      12, (i) => Group(id: '$i', name: 'Group $i', ownerId: viewer));
  @override
  Future<List<FlixieNotification>> notifications(String viewer) async => [];
  @override
  Future<List<GroupMember>> members(String id) async {
    started++;
    active++;
    if (active > peak) peak = active;
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    active--;
    return [
      GroupMember(
          groupId: id,
          memberId: 'viewer',
          role: 'OWNER',
          inviteStatus: 'ACCEPTED')
    ];
  }
}

void main() {
  test('People only loads friends, and latest refresh wins', () async {
    final auth = SocialAuth();
    final actions = Actions();
    final c = SocialPeopleController(auth: auth, actions: actions);
    final first = c.load(), second = c.load();
    actions.loads[1].complete(empty);
    await second;
    actions.loads[0].complete(const FriendsData(
        friendships: [request], pendingFriends: [], requestedFriends: []));
    await first;
    expect(c.data!.friendships, isEmpty);
    expect(auth.friends!.friendships, isEmpty);
    c.dispose();
    auth.dispose();
  });
  for (final disposed in [false, true]) {
    test('People rejects late ${disposed ? 'disposed' : 'account'} response',
        () async {
      final auth = SocialAuth();
      final actions = Actions();
      final c = SocialPeopleController(auth: auth, actions: actions);
      final work = c.load();
      if (disposed) {
        c.dispose();
      } else {
        auth.viewer = 'other';
      }
      actions.loads.single.complete(empty);
      await work;
      expect(auth.friends, isNull);
      if (!disposed) c.dispose();
      auth.dispose();
    });
  }
  test('accept is single flight, updates cache and preserves badge', () async {
    final auth = SocialAuth()
      ..friends = const FriendsData(
          friendships: [], pendingFriends: [request], requestedFriends: []);
    final actions = Actions();
    final c = SocialPeopleController(auth: auth, actions: actions);
    final work = c.respond(request, accept: true);
    expect(await c.respond(request, accept: true), isNull);
    actions.write.complete();
    expect(await work, isTrue);
    expect(actions.writes, 1);
    expect(auth.friends!.pendingFriends, isEmpty);
    expect(auth.friends!.friendships.single.friendUser!.profileBadges,
        ['EARLY_ADOPTER']);
    c.dispose();
    auth.dispose();
  });
  test('failed decline keeps pending request', () async {
    final auth = SocialAuth()
      ..friends = const FriendsData(
          friendships: [], pendingFriends: [request], requestedFriends: []);
    final c =
        SocialPeopleController(auth: auth, actions: Actions()..fail = true);
    expect(await c.respond(request, accept: false), isFalse);
    expect(c.data!.pendingFriends, [request]);
    c.dispose();
    auth.dispose();
  });
  test('confirmed response invalidates older read', () async {
    final auth = SocialAuth()
      ..friends = const FriendsData(
          friendships: [], pendingFriends: [request], requestedFriends: []);
    final actions = Actions();
    final c = SocialPeopleController(auth: auth, actions: actions);
    final read = c.load();
    final write = c.respond(request, accept: false);
    actions.write.complete();
    await write;
    actions.loads.single.complete(const FriendsData(
        friendships: [], pendingFriends: [request], requestedFriends: []));
    await read;
    expect(c.data!.pendingFriends, isEmpty);
    c.dispose();
    auth.dispose();
  });
  test('Groups refresh and account guards protect cache', () async {
    final auth = SocialAuth();
    final service = Groups();
    final c = SocialGroupsController(auth: auth, service: service);
    final first = c.load(), second = c.load();
    service.reads[1].complete(snapshot('new'));
    await second;
    service.reads[0].complete(snapshot('old'));
    await first;
    expect(c.groups.single.name, 'new');
    final third = c.load();
    auth.viewer = 'other';
    service.reads[2].complete(snapshot('wrong'));
    await third;
    expect(auth.groups!.single.name, 'new');
    c.dispose();
    auth.dispose();
  });
  test('group creation invalidates an older list read', () async {
    final auth = SocialAuth();
    final service = Groups();
    final c = SocialGroupsController(auth: auth, service: service);
    final read = c.load();
    c.addCreated(
        const Group(id: 'created', name: 'Created', ownerId: 'viewer'));
    service.reads.single.complete(snapshot('old'));
    await read;
    expect(c.groups.single.id, 'created');
    c.dispose();
    auth.dispose();
  });
  test('membership enrichment has four workers and complete projection',
      () async {
    final service = Memberships();
    final work = service.load('viewer');
    for (var batch = 0; batch < 3; batch++) {
      await Future<void>.delayed(Duration.zero);
      expect(service.active, 4);
      for (final gate in service.gates.where((g) => !g.isCompleted).toList()) {
        gate.complete();
      }
    }
    final result = await work;
    expect(service.peak, 4);
    expect(result.members, hasLength(12));
  });
  test('stale membership load stops scheduling further groups', () async {
    final service = Memberships();
    var current = true;
    final work = service.load('viewer', owns: () => current);
    await Future<void>.delayed(Duration.zero);
    current = false;
    for (final gate in service.gates) {
      gate.complete();
    }
    await work;
    expect(service.started, 4);
  });
}
