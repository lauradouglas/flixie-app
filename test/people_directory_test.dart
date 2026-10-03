import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/people_directory.dart';

class _Service extends CommunityService {
  bool followed = true;
  @override
  Future<List<FriendshipUser>> followedPeople() async =>
      [const FriendshipUser(id: 'a', username: 'Avery')];
  @override
  Future<void> follow(String path, bool value, {bool list = false}) async {
    followed = value;
  }
}

void main() {
  testWidgets('background star failure stays in Social and retry recovers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var fail = true;
    var requests = 0;
    ApiClient.useClientForTesting(MockClient((request) async {
      requests++;
      return fail ? http.Response('{}', 403) : http.Response('{"ids":[]}', 200);
    }));
    addTearDown(() => ApiClient.useClientForTesting(null));
    Widget screen(bool hidden) => MaterialApp(
            home: Scaffold(
                body: Column(children: [
          const Text('Home'),
          Offstage(
              offstage: hidden,
              child: PeopleDirectory(
                  userId: 'star-error-fixture',
                  friends: const [],
                  service: _Service())),
        ])));
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Couldn’t sync starred people.'), findsNothing);
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t sync starred people.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t sync starred people.'), findsNothing);
    expect(requests, greaterThanOrEqualTo(2));
  });
  testWidgets('stars persist privately and following can be removed',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final stars = <String>{};
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.method == 'PUT' && request.url.path.endsWith('/star')) {
        final id = request.url.path.split('/').reversed.skip(1).first;
        if (jsonDecode(request.body)['starred'] == true) {
          stars.add(id);
        } else {
          stars.remove(id);
        }
      }
      return http.Response(jsonEncode({'ids': stars.toList()}), 200);
    }));
    addTearDown(() => ApiClient.useClientForTesting(null));
    final service = _Service();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PeopleDirectory(
                    userId: 'me',
                    friends: const [
                      FriendshipUser(id: 'a', username: 'Avery'),
                      FriendshipUser(id: 'b', username: 'Bea')
                    ],
                    service: service)))));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Star Avery'));
    await tester.pumpAndSettle();
    expect(find.text('Starred'), findsOneWidget);
    expect(find.text('Avery'), findsOneWidget);
    expect(stars, {'a'});
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('@Avery · Friends'), findsOneWidget);
    await tester.tap(find.byTooltip('Unstar Avery'));
    await tester.pumpAndSettle();
    expect(stars, isEmpty);
    await tester.tap(find.byTooltip('Star Avery'));
    await tester.pumpAndSettle();
    expect(stars, {'a'});
    await tester.tap(find.byTooltip('Following Avery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfollow'));
    await tester.pumpAndSettle();
    expect(service.followed, isFalse);
    await tester.tap(find.text('Friends 2'));
    await tester.pumpAndSettle();
    expect(find.text('Avery'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Bea');
    await tester.pumpAndSettle();
    expect(find.text('Avery'), findsNothing);
    expect(find.text('@Bea'), findsOneWidget);
  });
}
