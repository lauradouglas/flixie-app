import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/ratings_section.dart';
import 'package:flixie_app/models/movie_rating.dart';

void main() {
  testWidgets('full ratings sheet searches all ratings and opens a movie',
      (tester) async {
    final ratings = List.generate(
        12,
        (i) => MovieRating(
              id: '$i',
              userId: 'fixture',
              movieId: i + 1,
              rating: 8,
              createdAt: '',
              updatedAt: '',
              movie: MovieRatingDetails(
                  id: i + 1, title: i == 11 ? 'Alien' : 'The Odyssey $i'),
            ));
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
              body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      useRootNavigator: true,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (_) => AllRatingsSheet(ratings: ratings)),
                  child: const Text('Ratings')))),
      GoRoute(
          path: '/movies/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Movie ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.lightTheme));
    await tester.tap(find.text('Ratings'));
    await tester.pumpAndSettle();
    expect(find.text('Search ratings...'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        3);
    await tester.enterText(find.byType(TextField), 'alien');
    await tester.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
    expect(find.text('The Odyssey 0'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing title');
    await tester.pumpAndSettle();
    expect(find.text('No ratings found.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'alien');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Alien'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alien'));
    await tester.pumpAndSettle();
    expect(find.text('Movie 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
