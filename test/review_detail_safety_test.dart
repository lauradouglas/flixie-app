import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/models/review.dart';

void main() {
  setUp(SafetyService.reset);
  Future<void> open(WidgetTester tester,
      {String? viewer = 'viewer', bool show = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showReviewDetailSheet(context,
                        review: Review.fromJson({
                          'id': 'review',
                          'userId': 'author',
                          if (show) 'showId': 42 else 'movieId': 42,
                          'title': 'Review title',
                          'body': 'Review body',
                          'rating': 8,
                          'user': {'id': 'author', 'username': 'Author'}
                        }),
                        currentUserId: viewer),
                    child: const Text('Open review'))))));
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
  }

  for (final show in [false, true]) {
    testWidgets(
        'reports the correct ${show ? 'TV' : 'movie'} review and author',
        (tester) async {
      Map<String, dynamic>? sent;
      await http.runWithClient(() async {
        await open(tester, show: show);
        await tester.tap(find.text('Report review'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Something else'));
        await tester.pumpAndSettle();
        expect(sent?['targetType'], show ? 'SHOW_REVIEW' : 'MOVIE_REVIEW');
        expect(sent?['targetId'], 'review');
        expect(sent?['reportedUserId'], 'author');
        expect(sent?['contentPreview'], 'Review title\nReview body');
        expect(find.byType(ReviewDetailSheet), findsOneWidget);
      },
          () => MockClient((request) async {
                expect(request.url.path, '/safety/reports');
                sent = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response('{}', 201);
              }));
    });
  }

  testWidgets('block cancellation preserves review; confirmed block closes it',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await open(tester);
      await tester.tap(find.text('Block user'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(ReviewDetailSheet), findsOneWidget);
      await tester.tap(find.text('Block user'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(SafetyService.isBlocked('author'), isTrue);
      expect(find.byType(ReviewDetailSheet), findsNothing);
    },
        () => MockClient((request) async {
              calls++;
              expect(request.url.path, '/safety/blocks');
              expect(jsonDecode(request.body)['blockedUserId'], 'author');
              return http.Response('{}', 200);
            }));
  });

  testWidgets(
      'owners and signed-out viewers do not see report or block actions',
      (tester) async {
    for (final viewer in ['author', null]) {
      await open(tester, viewer: viewer);
      expect(find.text('Report review'), findsNothing);
      expect(find.text('Block user'), findsNothing);
      await tester.tap(find.byTooltip('Close review'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'safety actions remain reachable on a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await tester.ensureVisible(find.text('Block user'));
    expect(find.text('Block user').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
