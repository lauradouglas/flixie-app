import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_detail_hero.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_header_backdrop.dart';
import 'package:flixie_app/models/movie.dart';

void main() {
  testWidgets(
      'backdrop reserves artwork space while absent and blank paths keep the original height',
      (tester) async {
    Widget header(String? backdrop) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MovieDetailHero(
                    movie:
                        Movie(id: 348, title: 'Alien', backdropPath: backdrop),
                    onShowScoreInfo: () {}))));
    await tester.pumpWidget(header(null));
    final size = tester.getSize(find.byType(MovieDetailHero));
    expect(find.byType(MovieHeaderBackdrop), findsNothing);
    await tester.pumpWidget(header('/alien-backdrop.jpg'));
    expect(
        tester.getSize(find.byType(MovieDetailHero)).height, size.height + 190);
    expect(find.byType(MovieHeaderBackdrop), findsOneWidget);
    final image = tester.widget<CachedNetworkImage>(find.descendant(
        of: find.byType(MovieHeaderBackdrop),
        matching: find.byType(CachedNetworkImage)));
    expect(
        image.imageUrl, 'https://image.tmdb.org/t/p/w1280/alien-backdrop.jpg');
    final context = tester.element(find.byType(MovieHeaderBackdrop));
    expect(image.errorWidget!(context, image.imageUrl, Exception('offline')),
        isA<SizedBox>());
    expect(image.placeholder!(context, image.imageUrl), isA<SizedBox>());
    await tester.pumpWidget(header('  '));
    expect(find.byType(MovieHeaderBackdrop), findsNothing);
    expect(tester.getSize(find.byType(MovieDetailHero)), size);
    expect(tester.takeException(), isNull);
  });
}
