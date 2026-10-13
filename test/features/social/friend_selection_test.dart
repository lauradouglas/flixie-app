import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/social/presentation/utils/friend_selection.dart';

void main() {
  const people = [
    FriendshipUser(id: 'one', username: 'AlienFan', firstName: 'Casey'),
    FriendshipUser(id: 'two', username: 'OdysseyFan', firstName: 'Robin'),
    FriendshipUser(id: 'three', username: 'SpiderFan', firstName: 'Casey'),
    FriendshipUser(id: 'four', username: 'ObsessionFan'),
  ];
  test('starred friends come first with stable order and source unchanged', () {
    final visible =
        selectFriends(people, userOf: (p) => p, starred: {'two', 'four'});
    expect(visible.map((p) => p.id), ['two', 'four', 'one', 'three']);
    expect(people.first.id, 'one');
  });
  test('name and username matching keeps starred matches first', () {
    expect(
        selectFriends(people,
                userOf: (p) => p, starred: {'three'}, query: ' CASEY ')
            .map((p) => p.id),
        ['three', 'one']);
    expect(
        selectFriends(people, userOf: (p) => p, starred: {}, query: 'Odyssey')
            .single
            .id,
        'two');
    expect(
        selectFriends(people,
            userOf: (p) => p, starred: {'two'}, query: 'missing'),
        isEmpty);
  });
}
