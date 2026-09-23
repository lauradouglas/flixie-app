import 'package:flixie_app/models/movie.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/collections/movie_collection.dart';
import 'package:flixie_app/features/collections/movie_collection_card.dart';
import 'package:flixie_app/features/collections/collection_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User get dbUser => const User(
      id: 'me',
      username: 'Me',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> fixture() => {
      'name': 'The Avengers Collection',
      'overview': '',
      'films': [
        {
          'id': 1,
          'title': 'The Avengers',
          'releaseDate': '2012-05-01',
          'watched': true,
          'rating': 8
        },
        {
          'id': 2,
          'title': 'Avengers: Age of Ultron',
          'releaseDate': '2015-05-01'
        },
        {
          'id': 3,
          'title': 'Avengers: Infinity War',
          'releaseDate': '2018-05-01',
          'onWatchlist': true
        },
        {
          'id': 4,
          'title': 'Avengers: Endgame',
          'releaseDate': '2019-05-01',
          'watched': true,
          'rating': 9
        },
        {'id': 5, 'title': 'Future film', 'releaseDate': '2099-05-01'},
      ]
    };
void main() {
  test('movie collection survives serialization', () {
    final movie = Movie.fromJson({
      'id': 4,
      'title': 'Endgame',
      'collection': {'id': 10, 'name': 'Avengers'}
    });
    expect(Movie.fromJson(movie.toJson()).collection?['id'], 10);
  });

  testWidgets('capture collection with app theme', (tester) async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ApiClient.useClientForTesting(
        MockClient((_) async => http.Response(jsonEncode(fixture()), 200)));
    addTearDown(() => ApiClient.useClientForTesting(null));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: RepaintBoundary(
            key: key, child: const CollectionScreen(collectionId: 10))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/flixie-collection-screen.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  test(
      'progress excludes unreleased films; watch-rest excludes watched and already saved',
      () {
    final data = MovieCollection(fixture());
    expect(data.released.length, 4);
    expect(data.watchedCount, 2);
    expect(data.toAdd.map((f) => f.id), [2, 5]);
  });
  testWidgets(
      'movie card opens collection; partial adds retry only failed films',
      (tester) async {
    final added = <int>[];
    var fail = true;
    ApiClient.useClientForTesting(MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode(fixture()), 200);
      }
      final id = int.parse(request.url.path.split('/').last);
      added.add(id);
      if (id == 5 && fail) return http.Response('{"message":"Try again"}', 400);
      return http.Response(
          jsonEncode({
            'id': 'entry-$id',
            'userId': 'me',
            'movieId': id,
            'removed': false
          }),
          200);
    }));
    addTearDown(() => ApiClient.useClientForTesting(null));
    final auth = _Auth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
            home: Scaffold(
                body: MovieCollectionCard(collection: {
          'id': 10,
          'name': 'The Avengers Collection'
        })))));
    await tester.tap(find.text('The Avengers Collection'));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionScreen), findsOneWidget);
    expect(find.text('2 of 4 released films watched'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Watch this collection'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Watch this collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch this collection'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add 2 films to watchlist'), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add 2 films to watchlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 films to watchlist'));
    await tester.pumpAndSettle();
    expect(added, [2, 5]);
    expect(find.textContaining('Some films couldn’t'), findsOneWidget);
    fail = false;
    await tester.scrollUntilVisible(find.text('Add 1 film to watchlist'), 100,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 film to watchlist'));
    await tester.pumpAndSettle();
    expect(added, [2, 5, 5]);
    expect(find.text('Watch the rest'), findsNothing);
    expect(find.text('Remaining films on your watchlist'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'collection and watch-rest sheet reflow at narrow large-text and tablet sizes',
      (tester) async {
    ApiClient.useClientForTesting(
        MockClient((_) async => http.Response(jsonEncode(fixture()), 200)));
    addTearDown(() => ApiClient.useClientForTesting(null));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _Auth();
    addTearDown(auth.dispose);
    for (final size in [
      const Size(320, 568),
      const Size(844, 390),
      const Size(1024, 1366)
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: CollectionScreen(key: ValueKey(size), collectionId: 10))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Watch this collection'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Watch this collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch this collection'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'sheet $size');
      await tester.scrollUntilVisible(find.text('Cancel'), 180,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });
}
