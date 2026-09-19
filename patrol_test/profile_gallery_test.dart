import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favorite_movies_section.dart';
import 'package:flixie_app/models/favorite_movie.dart';

void main() {
  patrolTest('all ten favourites remain reachable with large text', ($) async {
    final movies = List.generate(
        10,
        (i) => FavoriteMovie(
              id: 'f-$i',
              movieId: i + 1,
              userId: 'fixture',
              rank: i + 1,
              movie: {
                'title': i == 9 ? 'Spider-Man: Brand New Day' : 'Film ${i + 1}'
              },
            ));
    await $.pumpWidgetAndSettle(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!),
      home: Scaffold(
          body: SafeArea(
              child: SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: FavoriteMoviesSection(favoriteMovies: movies)),
      ))),
    ));
    await $(find.byTooltip('See all favourite movies')).tap();
    await $.tester.scrollUntilVisible(
        find.text('Spider-Man: Brand New Day'), 200,
        scrollable: find.descendant(
            of: find.byType(GridView), matching: find.byType(Scrollable)));
    await $.pumpAndSettle();
    expect(find.text('Spider-Man: Brand New Day'), findsOneWidget);
    expect($.tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
