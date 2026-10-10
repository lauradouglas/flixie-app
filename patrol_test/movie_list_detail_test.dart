import 'package:flutter/material.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_list_detail/movie_list_poster_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/api_fixture.dart';
import 'support/movie_list_detail_fixture.dart';

void main() {
  patrolTest('mixed list adds a movie and show then removes only the movie',
      ($) async {
    SharedPreferences.setMockInitialValues({});
    final api = MovieListDetailFixture();
    final auth = ListDetailAuth();
    final router = movieListFixtureRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(api.client);
    await $.pumpWidgetAndSettle(movieListFixtureApp(auth, router));
    await $(find.byTooltip('Add titles')).tap();
    await $(find.byType(TextField)).enterText('Spider');
    await $(find.byTooltip('Add Spider-Man')).waitUntilVisible();
    await $(find.byTooltip('Add Spider-Man')).tap();
    await $('Added').waitUntilVisible();
    await $(find.byTooltip('Add Obsession TV')).tap();
    await $.pumpAndSettle();
    expect(find.text('Added'), findsNWidgets(2));
    await $(find.byTooltip('Close')).tap();
    expect(api.entries.where((e) => e['movieId'] == 3), hasLength(1));
    expect(api.entries.where((e) => e['showId'] == 3), hasLength(1));
    await $(find.descendant(of: find.byWidgetPredicate((w) => w is MovieListPosterCard && w.entry.movieId == 3), matching: find.byTooltip('List item actions'))).tap();
    await $('Remove from list').tap();
    await $('Remove').tap();
    expect(api.entries.where((e) => e['movieId'] == 3), isEmpty);
    expect(api.entries.where((e) => e['showId'] == 3), hasLength(1));
    expect(api.unexpected, isEmpty);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Fixture collection').waitUntilVisible();
  });
  patrolTest('owner adds and removes a member without leaving the list route',
      ($) async {
    SharedPreferences.setMockInitialValues({});
    final api = MovieListDetailFixture();
    final auth = ListDetailAuth();
    final router = movieListFixtureRouter();
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(api.client);
    await $.pumpWidgetAndSettle(movieListFixtureApp(auth, router));
    await $(find.byTooltip('List actions')).tap();
    await $('View members').tap();
    await $('Add').tap();
    await $('@list-new-friend').tap();
    await $('Fixture collection').waitUntilVisible();
    expect(api.members, hasLength(3));
    await $(find.byTooltip('List actions')).tap();
    await $('View members').tap();
    await $(find.byTooltip('Remove member').first).tap();
    await $('Fixture collection').waitUntilVisible();
    expect(api.members, hasLength(2));
    expect(find.text('Lists destination'), findsNothing);
    expect(api.unexpected, isEmpty);
  });
  patrolTest('collaborator cancels then leaves a shared list', ($) async {
    SharedPreferences.setMockInitialValues({});
    final api = MovieListDetailFixture()..owner = false;
    final auth = ListDetailAuth()..switchViewer('list-friend');
    final router = movieListFixtureRouter(ownerId: 'list-owner');
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    useApiFixture(api.client);
    await $.pumpWidgetAndSettle(movieListFixtureApp(auth, router));
    await $(find.byTooltip('List actions')).tap();
    await $('Leave list').tap();
    await $('Cancel').tap();
    expect(api.writes, isEmpty);
    await $(find.byTooltip('List actions')).tap();
    await $('Leave list').tap();
    await $('Leave').tap();
    await $('Lists destination').waitUntilVisible();
    expect(api.members, ['list-owner']);
    expect(api.unexpected, isEmpty);
  });
}
