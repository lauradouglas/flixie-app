import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import '../test/support/api_fixture.dart';
import 'package:flixie_app/features/collections/movie_collection_card.dart';
import 'support/fixture_app.dart';

void main() {
  patrolTest('collection adds only unwatched films missing from watchlist',
      ($) async {
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    final added = <int>[];
    useApiFixture(MockClient((request) async {
      if (request.method == 'POST') {
        final id = int.parse(request.url.path.split('/').last);
        added.add(id);
        return http.Response(
            jsonEncode(
                {'id': 'entry-$id', 'userId': 'patrol-viewer', 'movieId': id}),
            200);
      }
      return http.Response(
          jsonEncode({
            'name': 'Test collection',
            'films': [
              {
                'id': 1,
                'title': 'Watched film',
                'releaseDate': '2020-01-01',
                'watched': true
              },
              {
                'id': 2,
                'title': 'Already saved',
                'releaseDate': '2021-01-01',
                'onWatchlist': true
              },
              {'id': 3, 'title': 'Next film', 'releaseDate': '2022-01-01'},
            ]
          }),
          200);
    }));
    await $.pumpWidgetAndSettle(fixtureApp(
        auth,
        const Scaffold(
            body: SafeArea(
                child: MovieCollectionCard(
                    collection: {'id': 10, 'name': 'Test collection'})))));
    await $('Test collection').tap();
    await $('Watch this collection').waitUntilVisible();
    await $('Watch this collection').tap();
    await $('Add 1 film to watchlist').tap();
    await $('Remaining films on your watchlist').waitUntilVisible();
    expect(added, [3]);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Remaining films on your watchlist').waitUntilVisible();
  });
}
