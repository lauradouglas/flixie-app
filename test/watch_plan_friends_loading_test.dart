import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'support/api_fixture.dart';

Future<void> mountSheet(WidgetTester tester, {String? initialFriendId}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
        body: MovieWatchRequestSheet(
      movieId: null,
      movieTitle: null,
      requesterId: 'fixture-viewer',
      friends: const [],
      initialFriendId: initialFriendId,
      onSuccess: () {},
      onError: () {},
    )),
  ));
  await tester.pump();
}

http.Response friendsResponse() => http.Response(
    jsonEncode({
      'friendships': [
        {
          'id': 'fixture-edge',
          'friend': {
            'id': 'fixture-robin',
            'username': 'robin',
            'profileBadges': ['FOUNDER']
          },
        }
      ],
      'pendingFriends': [],
      'requestedFriends': [],
    }),
    200);

void main() {
  testWidgets(
      'uncached friends load and can be selected without leaving creation',
      (tester) async {
    final response = Completer<http.Response>();
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/friends/fixture-viewer') return response.future;
      return http.Response(
          request.url.path.endsWith('/watch-providers')
              ? '{"watchProviders":[]}'
              : '[]',
          200);
    }));
    await mountSheet(tester);
    expect(
        find.text('Add some friends to plan a watch together'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(friendsResponse());
    await tester.pumpAndSettle();
    expect(find.text('robin'), findsOneWidget);
    final avatar =
        tester.widget<ProfileAvatarView>(find.byType(ProfileAvatarView));
    expect(avatar.profileBadges, ['FOUNDER']);
    await tester.tap(find.text('robin'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'friend loading failure offers retry instead of claiming no friends',
      (tester) async {
    var attempts = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/friends/fixture-viewer') {
        attempts++;
        if (attempts == 1) {
          return http.Response('{"message":"Unavailable"}', 400);
        }
        return friendsResponse();
      }
      return http.Response(
          request.url.path.endsWith('/watch-providers')
              ? '{"watchProviders":[]}'
              : '[]',
          200);
    }));
    await mountSheet(tester);
    await tester.pumpAndSettle();
    expect(
        find.text('Add some friends to plan a watch together'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('robin'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(attempts, 2);
  });

  testWidgets('initial friend is selected after an uncached load',
      (tester) async {
    useApiFixture(MockClient((request) async =>
        request.url.path == '/friends/fixture-viewer'
            ? friendsResponse()
            : http.Response(
                request.url.path.endsWith('/watch-providers')
                    ? '{"watchProviders":[]}'
                    : '[]',
                200)));
    await mountSheet(tester, initialFriendId: 'fixture-robin');
    await tester.pumpAndSettle();
    expect(find.text('robin'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
