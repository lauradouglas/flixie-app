import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../../movie_detail_loading_test.dart' as fixture;
import 'package:flixie_app/features/movies/presentation/widgets/movie_detail_hero.dart';

void main() {
  testWidgets('tablet availability sits beside story and tabs remain usable',
      (t) async {
    t.view.physicalSize = const Size(1194, 834);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final auth = fixture.GuestAuth(), movies = fixture.DelayedMovies();
    addTearDown(auth.dispose);
    await t.pumpWidget(fixture.app(auth, movies, '348'));
    movies.core[348]!.complete(const Movie(
        id: 348,
        title: 'Alien',
        overview: 'A crew encounters an alien.',
        runtime: 117));
    movies.providers.complete([
      const WatchProvider(
          id: 1,
          providerName: 'Fixture Cinema',
          displayPriority: 1,
          logoPath: '',
          tvShows: true,
          movies: true,
          isVisible: true,
          supportsGb: true,
          supportsUs: true,
          availabilityTypes: {'flatrate', 'rent'})
    ]);
    movies.reviews.complete([]);
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(MovieDetailHero)).left, 0);
    expect(t.getRect(find.byType(MovieDetailHero)).width, 1194);
    expect(t.getTopLeft(find.text('Where to watch')).dx,
        greaterThan(t.getTopLeft(find.text('Story')).dx + 500));
    await t.tap(find.text('Rent'));
    await t.pumpAndSettle();
    expect(find.text('Available to rent'), findsOneWidget);
    t.view.physicalSize = const Size(820, 1180);
    await t.pumpAndSettle();
    expect(find.text('Available to rent'), findsOneWidget,
        reason: 'The provider tab survives orientation changes');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
