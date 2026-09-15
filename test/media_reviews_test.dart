import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_reviews_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/models/review.dart';

void main() {
  testWidgets('only owners see delete and can cancel without losing review',
      (tester) async {
    final review = Review.fromJson({
      'id': 'delete-test',
      'userId': 'owner',
      'movieId': 42,
      'title': 'My review',
      'body': 'Keep this review',
      'rating': 8
    });
    Future<void> mount(String viewer) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ReviewDetailSheet(
                  review: review,
                  currentUserId: viewer,
                  initialReactions: const {},
                  initialMyReaction: null,
                  onReactionChanged: (_, __) {},
                  displayName: 'Owner',
                  initials: 'O',
                  formattedDate: 'Today'))));
      await tester.pump();
    }

    await mount('other');
    expect(find.text('Delete review'), findsNothing);
    await mount('owner');
    await tester.ensureVisible(find.text('Delete review'));
    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this review?'), findsOneWidget);
    await tester.tap(find.text('Keep review'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this review'), findsOneWidget);
    expect(find.text('Delete this review?'), findsNothing);
  });
  testWidgets(
      'review sheet hides spoilers and reflows activity reactions at large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final review = Review.fromJson({
      'id': 'sheet',
      'movieId': 42,
      'title': 'A review with a longer title',
      'body': 'Protected review text',
      'rating': 8,
      'containsSpoilers': true
    });
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showReviewDetailSheet(context,
                        review: review, currentUserId: null),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Protected review text'), findsNothing);
    await tester.ensureVisible(find.text('Spoiler review · Reveal'));
    await tester.tap(find.text('Spoiler review · Reveal'));
    await tester.pumpAndSettle();
    expect(find.text('Protected review text'), findsOneWidget);
    await tester.ensureVisible(find.text('👎'));
    expect(find.text('👀'), findsOneWidget);
    expect(find.text('💯'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close review'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewDetailSheet), findsNothing);
  });
  for (final type in ['MOVIE', 'SHOW']) {
    test('$type retrieves persisted reviews with author badges', () async {
      await http.runWithClient(() async {
        final reviews = type == 'SHOW'
            ? await ShowService.getShowReviews(42, userId: 'viewer')
            : await MovieService().getMovieReviews(42, userId: 'viewer');
        expect(reviews.single.showId, type == 'SHOW' ? 42 : null);
        expect(reviews.single.rating, 8);
        expect(reviews.single.user!.profileBadges, ['founder']);
      },
          () => MockClient((request) async {
                expect(request.url.path, '/users/$type/42/reviews');
                expect(request.url.queryParameters['userId'], 'viewer');
                return http.Response(
                    jsonEncode([
                      {
                        'id': 'review',
                        '${type.toLowerCase()}Id': 42,
                        'rating': 8,
                        'user': {
                          'id': 'author',
                          'username': 'Friend',
                          'profileBadges': ['founder']
                        }
                      }
                    ]),
                    200);
              }));
    });
  }

  testWidgets(
      'loading and failure are distinct from empty, with retry and write actions',
      (tester) async {
    var retries = 0;
    var writes = 0;
    Future<void> show({bool loading = false, bool failed = false}) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: MediaReviewsSection(
          reviews: const [],
          currentUserId: null,
          loading: loading,
          failed: failed,
          onRetry: () => retries++,
          onWriteReview: () => writes++,
        ))));
    await show(loading: true);
    expect(find.text('Loading reviews…'), findsOneWidget);
    expect(find.textContaining('No reviews yet'), findsNothing);
    await show(failed: true);
    expect(find.textContaining('No reviews yet'), findsNothing);
    await tester.tap(find.text('Couldn’t load reviews · Retry'));
    expect(retries, 1);
    await tester.tap(find.text('Write review'));
    expect(writes, 1);
    await show();
    expect(find.textContaining('No reviews yet'), findsOneWidget);
  });

  testWidgets(
      'shared section limits preview and opens scrollable all-reviews sheet at large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reviews = List.generate(
        6,
        (i) => Review.fromJson({
              'id': '$i',
              'showId': 42,
              'title': 'Review $i',
              'body': 'A thoughtful review.',
              'rating': 8,
            }));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: MediaReviewsSection(
          reviews: reviews,
          currentUserId: null,
          onWriteReview: () {},
        )))));
    expect(find.byType(ReviewCard), findsNWidgets(4));
    await tester.ensureVisible(find.text('See all 6 reviews'));
    await tester.tap(find.text('See all 6 reviews'));
    await tester.pumpAndSettle();
    expect(find.text('All Reviews (6)'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('All Reviews (6)'), findsNothing);
  });
}
