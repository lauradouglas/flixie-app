import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/utils/notification_profile_badges.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/friendship.dart';

void main() {
  test('preview sender username, avatar and badges survive JSON parsing', () {
    final n = FlixieNotification.fromJson({
      'userId': 'me',
      'type': 'FRIEND_REQUEST',
      'senderUser': {
        'id': 'preview-user',
        'username': 'Dougasaur',
        'profileBadges': ['EARLY_ADOPTER'],
        'avatar': {
          'id': 9,
          'key': 'cavalier',
          'displayName': 'Cavalier',
          'storagePath': 'avatars/freddie_avatar.png'
        }
      },
    });
    expect(n.senderName, 'Dougasaur');
    expect(n.senderAvatar?.key, 'cavalier');
    expect(n.senderProfileBadges, ['EARLY_ADOPTER']);
  });
  const friends = FriendsData(friendships: [
    Friendship(id: 'empty', createdAt: '', updatedAt: ''),
    Friendship(
        id: 'known',
        createdAt: '',
        updatedAt: '',
        friend: FriendshipUser(
            id: 'ben', username: 'Ben', profileBadges: ['FOUNDER'])),
  ], pendingFriends: [], requestedFriends: []);
  const absent = FlixieNotification(
      userId: 'me', type: 'GROUP_INVITE', message: 'Join a group');
  test(
      'missing sender and empty friendship identities do not crash or borrow badges',
      () {
    expect(notificationProfileBadges(absent, friends), isEmpty);
    expect(notificationProfileBadges(absent, null), isEmpty);
  });
  test('known sender resolves their own cached border across nullable entries',
      () {
    final n = absent.copyWith(senderUser: {'id': 'ben'});
    expect(notificationProfileBadges(n, friends), ['FOUNDER']);
  });
  test('payload badges take priority over cached badges', () {
    final n = absent.copyWith(senderUser: {
      'id': 'ben',
      'profileBadges': ['VERIFIED']
    });
    expect(notificationProfileBadges(n, friends), ['VERIFIED']);
  });
}
