import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/add_friend_sheet.dart';
import '../social/social_controllers_test.dart' show SocialAuth;

void main() {
  testWidgets('existing friend appears as Already friends without an add action', (t) async {
    final auth = SocialAuth();
    addTearDown(auth.dispose);
    var writes = 0;
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.method == 'POST') writes++;
      if (request.url.path == '/friends/viewer') {
        return http.Response(jsonEncode({'friendships': [
          {'id': 'edge', 'friendId': 'maya', 'friend': {'id': 'maya', 'username': 'maya'}}
        ], 'pendingFriends': [], 'requestedFriends': []}), 200);
      }
      return http.Response(jsonEncode([{'id':'maya', 'username':'maya',
        'email':'maya@example.test', 'iconColorId':1, 'completedSetup':true, 'darkMode':true}]), 200);
    }));
    addTearDown(() => ApiClient.useClientForTesting(null));
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(value: auth,
      child: const MaterialApp(home: Scaffold(body: AddFriendSheet()))));
    await t.enterText(find.byType(TextField), 'maya');
    await t.tap(find.byTooltip('Search'));
    await t.pumpAndSettle();
    expect(find.text('Already friends'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add friend'), findsNothing);
    expect(writes, 0);
    expect(t.takeException(), isNull);
  });
}
