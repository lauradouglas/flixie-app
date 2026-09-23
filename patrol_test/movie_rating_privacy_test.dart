import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/movie_search_result_tile.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/settings/presentation/widgets/movie_rating_privacy_setting.dart';
import 'package:flixie_app/models/movie_short.dart';
import '../test/support/api_fixture.dart';

void main() {
  patrolTest('rate movies first hides public scores until a rating is saved',
      ($) async {
    // Patrol is an integration test, outside Dart’s test directory convention.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    useApiFixture(MockClient((request) async => http.Response(
          jsonEncode(request.method == 'GET' ? [] : {'rating': 7}),
          200,
          headers: {'content-type': 'application/json'},
        )));
    final privacy = MovieRatingPrivacy.instance;
    privacy.syncUser('privacy-test-user');
    addTearDown(() => privacy.syncUser(null));
    await $.pumpWidgetAndSettle(ChangeNotifierProvider.value(
        value: privacy,
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
                body: SafeArea(
              child: SingleChildScrollView(
                  child: Column(children: [
                const MovieRatingPrivacySetting(),
                const MovieSearchResultTile(
                    movie: MovieShort(
                        id: 77, name: 'Fixture movie', voteAverage: 8.4)),
                FilledButton(
                    onPressed: () async {
                      await MovieService()
                          .addMovieRating(77, 'privacy-test-user', 7, null);
                    },
                    child: const Text('Save my rating')),
              ])),
            )))));
    expect(find.text('8.4'), findsOneWidget);
    await $(Switch).tap();
    await $.pumpAndSettle();
    expect(find.text('8.4'), findsNothing);
    await $('Save my rating').tap();
    await $('8.4').waitUntilVisible();
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('8.4').waitUntilVisible();
  });
}
