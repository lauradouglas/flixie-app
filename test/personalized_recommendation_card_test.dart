import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/personalized_recommendation_card.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  testWidgets('personalised card keeps a 2:3 poster and shows its reason',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 330,
            child: PersonalizedRecommendationCard(
              movie: const MovieShort(
                id: 1,
                name: 'Arrival',
                releaseDate: '2016-11-10',
                voteAverage: 8.1,
              ),
              reasons: const [
                'Matches your interest in first contact',
                'Because you enjoy Science Fiction',
                'From a director you tend to enjoy',
              ],
              isBookmarked: false,
              isBookmarkUpdating: false,
              isPreviouslyWatched: false,
              onTap: () {},
              onBookmarkTap: () {},
              onMarkWatched: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Matches your interest in first contact'), findsOneWidget);
    expect(find.text('Because you enjoy Science Fiction'), findsOneWidget);
    expect(find.text('From a director you tend to enjoy'), findsOneWidget);
    expect(find.byTooltip('Mark watched'), findsOneWidget);
    expect(find.text('2016 · Movie'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final posterBox =
        tester.widgetList<SizedBox>(find.byType(SizedBox)).firstWhere(
              (box) => box.width == PersonalizedRecommendationCard.posterWidth,
            );
    expect(
      posterBox.width! / posterBox.height!,
      closeTo(2 / 3, 0.001),
    );
  });

  testWidgets('previously watched recommendation offers a rewatch',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalizedRecommendationCard(
            movie: const MovieShort(id: 1, name: 'Arrival'),
            reasons: const [
              'You enjoyed this before - it may be worth a rewatch'
            ],
            isBookmarked: false,
            isBookmarkUpdating: false,
            isPreviouslyWatched: true,
            onTap: () {},
            onBookmarkTap: () {},
            onMarkWatched: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Log another watch'), findsOneWidget);
    expect(find.byIcon(Icons.replay_circle_filled_rounded), findsOneWidget);
  });
}
