import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/profile/presentation/pages/friend_profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/pages/milestones_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get dbUser => const User(
      id: 'me',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final friends in [true, false]) {
    testWidgets('current profile milestones access: friends=$friends',
        (tester) async {
      final requests = <String>[];
      ApiClient.useClientForTesting(MockClient((request) async {
        final path = request.url.path;
        requests.add(path);
        Object data = [];
        if (path.endsWith('/users/friend')) {
          data = {
            'id': 'friend',
            'username': 'LauraD',
            'email': '',
            'iconColorId': 0,
            'completedSetup': true,
            'darkMode': true
          };
        } else if (path.endsWith('/friends/me')) {
          data = {
            'friendships': friends
                ? [
                    {
                      'id': 'edge',
                      'friend': {'id': 'friend', 'username': 'LauraD'}
                    }
                  ]
                : [],
            'pendingFriends': [],
            'requestedFriends': []
          };
        } else if (path.endsWith('/activity')) {
          data = {'items': [], 'nextCursor': null};
        } else if (path.endsWith('/milestones')) {
          data = {'visibility': 'friends', 'items': []};
        }
        return http.Response(jsonEncode(data), 200);
      }));
      addTearDown(() => ApiClient.useClientForTesting(null));
      final auth = _Auth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child:
              const MaterialApp(home: FriendProfileScreen(userId: 'friend'))));
      await tester.pumpAndSettle();
      final link = find.text('View earned milestones');
      if (friends) {
        expect(link, findsOneWidget);
        await tester.ensureVisible(link);
        await tester.pumpAndSettle();
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(MilestonesScreen), findsOneWidget);
        expect(find.text('LauraD’s movie moments'), findsOneWidget);
        expect(
            requests.any((path) => path.endsWith('/users/friend/milestones')),
            isTrue);
      } else {
        expect(link, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
