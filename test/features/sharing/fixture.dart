import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/friendship.dart';

class ShareAuth extends ChangeNotifier implements AuthProvider {
  String? id = 'fixture-viewer';
  FriendsData? friends;
  List<Group>? groups;
  int publications = 0;
  @override
  User? get dbUser => id == null
      ? null
      : User(
          id: id!,
          username: 'OdysseyFan',
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
    publications++;
    notifyListeners();
  }

  @override
  void updateCachedGroups(List<Group> value) {
    groups = value;
    publications++;
    notifyListeners();
  }

  void change(String? next) {
    id = next;
    friends = null;
    groups = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> friendsPayload(int count) => {
      'friendships': [
        for (var i = 0; i < count; i++)
          {
            'id': 'edge-$i',
            'friend': {
              'id': 'friend-$i',
              'username': i == 0 ? 'AlienFan' : 'OdysseyFan$i',
              'profileBadges': ['FOUNDER']
            }
          }
      ]
    };
List<Map<String, dynamic>> groupsPayload(int count) => [
      for (var i = 0; i < count; i++)
        {
          'id': 'group-$i',
          'name': i == 0 ? 'Alien Club' : 'Odyssey Club $i',
          'ownerId': 'fixture-viewer'
        }
    ];
