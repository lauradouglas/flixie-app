import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/models/review.dart';

void main() {
  setUp(SafetyService.reset);
  Widget card() => MaterialApp(
          home: Scaffold(
              body: ReviewCard(
        review: Review.fromJson({
          'id': 'r',
          'userId': 'author',
          'title': 'Private review title',
          'body': 'Review body',
          'rating': 8
        }),
        currentUserId: 'viewer',
      )));

  testWidgets(
      'blocked reviews never appear while the first safety request is pending',
      (tester) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(card());
      expect(find.text('Private review title'), findsNothing);
      expect(find.text('Loading review…'), findsOneWidget);
      response.complete(
          http.Response('[{"id":"author","username":"Author"}]', 200));
      await tester.pumpAndSettle();
      expect(find.text('Private review title'), findsNothing);
      expect(find.text('Loading review…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) => response.future));
  });

  testWidgets(
      'failed safety lookup hides content, retries, and responds to block changes',
      (tester) async {
    var fail = true;
    var blocked = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(card());
      await tester.pumpAndSettle();
      expect(find.text('Private review title'), findsNothing);
      expect(find.text('Couldn’t load review · Retry'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Couldn’t load review · Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Private review title'), findsOneWidget);
      await SafetyService.block('author');
      await tester.pumpAndSettle();
      expect(find.text('Private review title'), findsNothing);
      await SafetyService.unblock('author');
      await tester.pumpAndSettle();
      expect(find.text('Private review title'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                blocked = true;
                return http.Response('{}', 200);
              }
              if (request.method == 'DELETE') {
                blocked = false;
                return http.Response('{}', 200);
              }
              if (fail) return http.Response('{}', 403);
              return http.Response(
                  blocked ? '[{"id":"author","username":"Author"}]' : '[]',
                  200);
            }));
  });
}
