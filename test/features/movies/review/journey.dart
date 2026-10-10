import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/models/review.dart';
import '../../../support/api_fixture.dart';

Future<void> reactionJourney(WidgetTester tester) async {
  SafetyService.reset();
  final calls = <String?>[];
  useApiFixture(MockClient((request) async {
    if (request.url.path == '/safety/blocks') return http.Response('[]', 200);
    expect(request.url.path, '/users/MOVIE/42/review/odyssey-review/react');
    final type = jsonDecode(request.body)['reactionType'] as String?;
    calls.add(type);
    if (calls.length == 1) return http.Response('{}', 503);
    return http.Response(
        jsonEncode({
          'reactions': type == null ? {} : {type: 1},
          'myReaction': type
        }),
        200);
  }));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ReviewCard(
              currentUserId: 'viewer',
              review: Review.fromJson({
                'id': 'odyssey-review',
                'movieId': 42,
                'userId': 'author',
                'title': 'The Odyssey',
                'body': 'A journey worth sharing',
                'createdAt': '2026-10-09',
                'rating': 8,
                'user': {
                  'id': 'author',
                  'username': 'AlienFan',
                  'profileBadges': ['FOUNDER']
                },
              })))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('The Odyssey'));
  await tester.pumpAndSettle();
  expect(find.byType(ReviewDetailSheet), findsOneWidget);
  await tester.ensureVisible(find.text('❤️'));
  await tester.tap(
      find.ancestor(of: find.text('❤️'), matching: find.byType(FlixiePill)));
  await tester.pumpAndSettle();
  expect(calls, ['love']);
  expect(
      find.text('1'), findsNothing); // Failed optimistic reaction rolled back.
  await tester.tap(
      find.ancestor(of: find.text('❤️'), matching: find.byType(FlixiePill)));
  await tester.pumpAndSettle();
  expect(calls, ['love', 'love']);
  expect(find.text('1'), findsOneWidget);
  await tester.ensureVisible(find.byTooltip('Close review'));
  await tester.tap(find.byTooltip('Close review'));
  await tester.pumpAndSettle();
  expect(
      find.text('❤️ 1'), findsOneWidget); // Sheet updates the collapsed card.
  await tester.tap(find.text('The Odyssey'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('❤️'));
  await tester.tap(
      find.ancestor(of: find.text('❤️'), matching: find.byType(FlixiePill)));
  await tester.pumpAndSettle();
  expect(calls, ['love', 'love', null]);
  await tester.ensureVisible(find.byTooltip('Close review'));
  await tester.tap(find.byTooltip('Close review'));
  await tester.pumpAndSettle();
  expect(find.text('❤️ 1'), findsNothing);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}
