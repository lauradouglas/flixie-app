import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/features/home/presentation/widgets/tablet_trending_gallery.dart';
import 'package:flixie_app/models/movie_short.dart';
import '../../support/api_fixture.dart';

void main() {
  test(
      'one combined request retains ranked movie/show order and filters people',
      () async {
    final paths = <String>[];
    useApiFixture(MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
          jsonEncode([
            {'id': 348, 'name': 'Alien', 'mediaType': 'MOVIE'},
            {'id': 348, 'name': 'Game of Thrones', 'mediaType': 'SHOW'},
            {'id': 1, 'name': 'A person', 'mediaType': 'PERSON'},
          ]),
          200);
    }));
    final items = await TrendingService.getTrendingMedia(refresh: true);
    expect(paths, ['/trending/all/day']);
    expect(items.map((item) => item.name), ['Alien', 'Game of Thrones']);
    expect(items.map((item) => item.homeKey), [348, -348]);
  });
  testWidgets(
      'tablet selecting a show with same movie ID sends show details and save',
      (tester) async {
    tester.view.physicalSize = const Size(834, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MovieShort? opened, saved;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TabletTrendingGallery(
                    movies: const [
          MovieShort(id: 348, name: 'Alien', mediaType: 'MOVIE'),
          MovieShort(id: 348, name: 'Game of Thrones', mediaType: 'SHOW')
        ],
                    savedIds: const {
          348
        },
                    pendingIds: const {},
                    onDetails: (item) => opened = item,
                    onSave: (item) => saved = item,
                    onTrailer: (_) {})))));
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('trending-poster--348')), matching: find.byType(InkWell)).first);
    await tester.pump();
    expect(find.text('TV show'), findsOneWidget);
    await tester.tap(find.text('Game of Thrones').first);
    expect(opened?.isShow, isTrue);
    await tester.tap(find.text('Add to watchlist'));
    expect(saved?.isShow, isTrue);
    expect(tester.takeException(), isNull);
  });
}
