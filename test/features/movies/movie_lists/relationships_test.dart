import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/controllers/list_editor_relationships.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_list.dart';

const empty =
    FriendsData(friendships: [], pendingFriends: [], requestedFriends: []);
void main() {
  test(
      'personal does no work; repeated friends loads coalesce and reuse success',
      () async {
    var friendReads = 0, groupReads = 0;
    final result = Completer<FriendsData>();
    final owner = ListEditorRelationships(
        userId: 'fixture',
        isCurrentUser: () => true,
        loadFriends: (_) {
          friendReads++;
          return result.future;
        },
        loadGroups: (_) async {
          groupReads++;
          return [];
        });
    addTearDown(owner.dispose);
    await owner.load(ListScope.personal);
    expect(friendReads + groupReads, 0);
    final first = owner.load(ListScope.friends);
    await owner.load(ListScope.friends);
    expect(friendReads, 1);
    result.complete(empty);
    await first;
    await owner.load(ListScope.personal);
    await owner.load(ListScope.friends);
    expect(friendReads, 1);
    expect(groupReads, 0);
  });
  test('group failure stays distinguishable from empty and retries', () async {
    var calls = 0;
    final owner = ListEditorRelationships(
        userId: 'fixture',
        isCurrentUser: () => true,
        loadGroups: (_) async {
          if (++calls == 1) throw StateError('offline');
          return const [
            Group(id: 'group', name: 'Alien fans', ownerId: 'fixture')
          ];
        });
    addTearDown(owner.dispose);
    await owner.load(ListScope.group);
    expect(owner.groupsError, isNotNull);
    expect(owner.groupsLoaded, false);
    await owner.load(ListScope.group);
    expect(owner.groupsError, isNull);
    expect(owner.groups.single.name, 'Alien fans');
    await owner.load(ListScope.group);
    expect(calls, 2);
  });
  for (final disposed in [false, true]) {
    test(
        'late friends response ignored after ${disposed ? 'disposal' : 'account change'}',
        () async {
      var current = true, notices = 0;
      final result = Completer<FriendsData>();
      final owner = ListEditorRelationships(
          userId: 'fixture',
          isCurrentUser: () => current,
          loadFriends: (_) => result.future);
      owner.addListener(() => notices++);
      final pending = owner.load(ListScope.friends);
      if (disposed) {
        owner.dispose();
      } else {
        current = false;
      }
      final before = notices;
      result.complete(empty);
      await pending;
      expect(notices, before);
      expect(owner.friendsLoaded, false);
      if (!disposed) owner.dispose();
    });
  }
}
