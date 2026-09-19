import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_ranking_sheet.dart';
import 'support/fixture_app.dart';

void main() {
  for (final shows in [false, true]) {
    final kind = shows ? 'shows' : 'movies';
    patrolTest('$kind ranking saves, confirms and survives reopening',
        ($) async {
      final auth = FixtureAuth(count: 3);
      addTearDown(auth.dispose);
      final originals = shows
          ? auth.dbUser.favoriteShows!.cast<Map<String, dynamic>>()
          : auth.dbUser.favoriteMovies!.map((e) => e.toJson()).toList();
      var saves = 0;
      await http.runWithClient(() async {
        await $.pumpWidgetAndSettle(fixtureApp(
            auth,
            Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () =>
                          showFavouriteRankingSheet(context, shows: shows),
                      child: const Text('Edit ranking'))),
            ),
            dark: shows));
        await $('Edit ranking').tap();
        await $(find.byTooltip('Move down').first).tap();
        await $('Save ranking').tap();
        await $('Favourite $kind ranking saved').waitUntilVisible();
        expect(saves, 1);
        expect(find.byType(BottomSheet), findsNothing);
        await $('Edit ranking').tap();
        final first = shows ? 'Show 2' : 'Film 2';
        final second = shows ? 'Show 1' : 'Film 1';
        expect($.tester.getTopLeft(find.text(first)).dy,
            lessThan($.tester.getTopLeft(find.text(second)).dy));
        expect(auth.activityVersion, 1);
      },
          () => MockClient((request) async {
                expect(request.method, 'PUT');
                expect(request.url.path,
                    '/users/patrol-viewer/${shows ? 'show' : 'movie'}/favorites/update-rankings');
                final ids = (jsonDecode(request.body)[kind] as List)
                    .map((e) => e['id'])
                    .toList();
                expect(ids, [
                  originals[1]['id'],
                  originals[0]['id'],
                  originals[2]['id']
                ]);
                saves++;
                return http.Response(
                    jsonEncode([
                      for (var i = 0; i < ids.length; i++)
                        {
                          ...originals.firstWhere((e) => e['id'] == ids[i]),
                          'rank': i + 1
                        },
                    ]),
                    200,
                    headers: {'content-type': 'application/json'});
              }));
    });

    patrolTest('$kind replacement removes only the chosen favourite',
        ($) async {
      final auth = FixtureAuth();
      addTearDown(auth.dispose);
      var continued = false;
      var deletes = 0;
      await http.runWithClient(() async {
        await $.pumpWidgetAndSettle(fixtureApp(
            auth,
            Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showFavouriteLimitPrompt(context,
                              type: shows
                                  ? FavouriteLimitType.show
                                  : FavouriteLimitType.movie,
                              onSpaceMade: () async {
                            continued = true;
                          }),
                      child: const Text('Add eleventh'))),
            )));
        await $('Add eleventh').tap();
        await $(shows ? 'Show 1' : 'Film 1').tap();
        await $('Remove selected and continue').tap();
        await $.pumpAndSettle();
        expect(deletes, 1);
        expect(continued, isTrue);
        expect(find.byType(BottomSheet), findsNothing);
        if (shows) {
          expect(auth.dbUser.favoriteShows!.length, 9);
          expect(auth.dbUser.favoriteShows!.first['showId'], 102);
          expect(auth.dbUser.favoriteMovies!.length, 10);
        } else {
          expect(auth.dbUser.favoriteMovies!.length, 9);
          expect(auth.dbUser.favoriteMovies!.first.movieId, 2);
          expect(auth.dbUser.favoriteShows!.length, 10);
        }
      },
          () => MockClient((request) async {
                expect(request.method, 'DELETE');
                expect(request.url.path,
                    '/users/patrol-viewer/${shows ? 'show' : 'movie'}/favorite/${shows ? 101 : 1}');
                deletes++;
                return http.Response('[]', 200,
                    headers: {'content-type': 'application/json'});
              }));
    });

    patrolTest('$kind at ten asks for replacement; cancel preserves all',
        ($) async {
      final auth = FixtureAuth();
      addTearDown(auth.dispose);
      var added = false;
      await $.pumpWidgetAndSettle(fixtureApp(
          auth,
          Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showFavouriteLimitPrompt(context,
                            type: shows
                                ? FavouriteLimitType.show
                                : FavouriteLimitType.movie,
                            onSpaceMade: () async {
                          added = true;
                        }),
                    child: const Text('Add eleventh'))),
          )));
      await $('Add eleventh').tap();
      await $('Which favourite should make room?').waitUntilVisible();
      final continueButton = find.ancestor(
          of: find.text('Select favourites to remove'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton));
      expect($.tester.widget<FilledButton>(continueButton).onPressed, isNull);
      await $(find.byIcon(Icons.close_rounded)).tap();
      expect(added, isFalse);
      expect(auth.dbUser.favoriteMovies!.length, 10);
      expect(auth.dbUser.favoriteShows!.length, 10);
    });
  }

  patrolTest('failed ranking save keeps editor open and allows retry',
      ($) async {
    final auth = FixtureAuth(count: 2);
    addTearDown(auth.dispose);
    var calls = 0;
    await http.runWithClient(() async {
      await $.pumpWidgetAndSettle(fixtureApp(
          auth,
          Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showFavouriteRankingSheet(context, shows: false),
                    child: const Text('Edit ranking'))),
          )));
      await $('Edit ranking').tap();
      await $(find.byTooltip('Move down').first).tap();
      await $('Save ranking').tap();
      await $('Couldn’t save your order. Please try again.').waitUntilVisible();
      expect(auth.dbUser.favoriteMovies!.first.movieId, 1);
      expect(find.byType(BottomSheet), findsOneWidget);
      await $('Save ranking').tap();
      await $('Favourite movies ranking saved').waitUntilVisible();
      expect(calls, 2);
      expect(auth.dbUser.favoriteMovies!.first.movieId, 2);
    },
        () => MockClient((request) async {
              calls++;
              if (calls == 1) {
                return http.Response('{"message":"Fixture failure"}', 400);
              }
              return http.Response(
                  jsonEncode(auth.dbUser.favoriteMovies!.reversed
                      .toList()
                      .asMap()
                      .entries
                      .map((e) => {...e.value.toJson(), 'rank': e.key + 1})
                      .toList()),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
}
