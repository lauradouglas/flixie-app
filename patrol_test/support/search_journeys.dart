// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import 'package:flixie_app/features/movies/presentation/widgets/search/search_results_view.dart';
import '../../test/support/api_fixture.dart';
import '../../test/support/watchlist_auth.dart';

class SearchAuth extends TestAuth {
  int count = 0;
  @override
  int get unreadNotificationCount => count;
  void notifyCount(int value) {
    count = value;
    notifyListeners();
  }
}

http.Response searchResponse(Object value, {int status = 200}) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'});
Map<String, Object> mediaPage({int page = 1, String type = 'movie'}) => {
      'page': page,
      'totalPages': 2,
      'totalResults': 2,
      'results': [
        if (type == 'movie')
          {
            'id': 348 + page - 1,
            'title': page == 1 ? 'Alien' : 'The Odyssey',
            'media_type': 'movie'
          }
        else if (type == 'tv')
          {'id': 157239, 'name': 'Alien: Earth', 'media_type': 'tv'}
        else
          {'id': 990000001, 'name': 'Casey Runtime', 'media_type': 'person'}
      ]
    };
Future<GoRouter> openSearch(PatrolTester $,
    {SearchAuth? auth, bool focus = false}) async {
  SharedPreferences.setMockInitialValues({});
  MovieCacheService().clearCache();
  final viewer = auth ?? SearchAuth();
  addTearDown(viewer.dispose);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => SearchScreen(focusSearch: focus)),
    for (final type in ['movies', 'shows', 'people', 'notifications'])
      GoRoute(
          path: type == 'notifications' ? '/notifications' : '/$type/:id',
          builder: (_, state) => Scaffold(
              appBar: AppBar(), body: Text('destination ${state.uri.path}'))),
  ]);
  addTearDown(router.dispose);
  await $.pumpWidgetAndSettle(ChangeNotifierProvider<AuthProvider>.value(
      value: viewer,
      child:
          MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router)));
  return router;
}

Future<void> submitSearch(PatrolTester $, String query) async {
  await $.tester.tap(find.byType(TextField));
  await $.pump();
  await $.tester.enterText(find.byType(TextField), query);
  await $.tester.testTextInput.receiveAction(TextInputAction.search);
  FocusManager.instance.primaryFocus?.unfocus();
  await $.pumpAndSettle();
}

Future<void> tapSearch(PatrolTester $, Finder finder) async {
  final buttons = find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
          (w) => w is ButtonStyleButton || w is IconButton || w is RawChip));
  final target = buttons.evaluate().isEmpty ? finder : buttons.first;
  await Scrollable.ensureVisible($.tester.element(target), alignment: .5);
  await $.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await $.tester.tap(target);
  await $.pumpAndSettle();
}

void searchJourneys(
    void Function(String, Future<void> Function(PatrolTester)) test) {
  test('Search keeps history, retries paging and changes media filters',
      ($) async {
    var failPage = true;
    final queries = <String>[];
    useApiFixture(MockClient((r) async {
      if (r.url.path.contains('trending')) return searchResponse([]);
      final page = int.parse(r.url.queryParameters['page']!);
      final type = r.url.queryParameters['type'] ?? 'collection';
      queries.add('$type:$page');
      if (page == 2 && failPage) {
        failPage = false;
        return searchResponse({}, status: 500);
      }
      return searchResponse(
          mediaPage(page: page, type: type == 'all' ? 'movie' : type));
    }));
    await openSearch($);
    await submitSearch($, 'Alien');
    await tapSearch($, find.text('Load more'));
    expect(find.text('Couldn’t load more results.'), findsOneWidget);
    await tapSearch($, find.text('Try again'));
    expect(find.text('The Odyssey', findRichText: true), findsOneWidget);
    expect(queries, ['all:1', 'all:2', 'all:2']);
    await tapSearch($, find.text('Shows'));
    expect(find.text('Alien: Earth', findRichText: true), findsOneWidget);
    await tapSearch($, find.text('People'));
    expect(find.text('Casey Runtime', findRichText: true), findsOneWidget);
    await tapSearch($, find.byTooltip('Clear search'));
    expect(find.text('Alien'), findsOneWidget);
    await tapSearch($, find.text('Clear all'));
    expect(find.text('Recent searches'), findsNothing);
  });
  test('Search retry after failed refresh rereads page one', ($) async {
    var fail = false;
    final pages = <int>[];
    useApiFixture(MockClient((r) async {
      if (r.url.path.contains('trending')) return searchResponse([]);
      final page = int.parse(r.url.queryParameters['page']!);
      pages.add(page);
      return searchResponse(fail ? {} : mediaPage(page: page),
          status: fail ? 500 : 200);
    }));
    await openSearch($);
    await submitSearch($, 'Alien');
    await tapSearch($, find.text('Load more'));
    fail = true;
    await $.tester
        .widget<FlixieRefresh>(find.byType(FlixieRefresh))
        .onRefresh();
    await $.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'Alien'),
        findsOneWidget);
    fail = false;
    await tapSearch($, find.text('Try again'));
    expect(pages, [1, 2, 1, 1]);
    expect(find.text('The Odyssey', findRichText: true), findsNothing);
  });
  test('Search collections keep results and retry a failed refresh', ($) async {
    var fail = false;
    var collectionReads = 0;
    useApiFixture(MockClient((r) async {
      if (r.url.path.contains('trending')) return searchResponse([]);
      if (r.url.path == '/search/collection') {
        collectionReads++;
        return searchResponse(
            fail
                ? {}
                : {
                    'page': 1,
                    'totalPages': 1,
                    'totalResults': 1,
                    'results': [
                      {'id': 10, 'name': 'Alien Collection'}
                    ]
                  },
            status: fail ? 500 : 200);
      }
      return searchResponse(mediaPage());
    }));
    await openSearch($);
    await submitSearch($, 'Alien');
    await $.tester.scrollUntilVisible(find.text('Collections'), 120,
        scrollable: find.descendant(
            of: find.byWidgetPredicate(
                (w) => w is ListView && w.scrollDirection == Axis.horizontal),
            matching: find.byType(Scrollable)));
    await tapSearch($, find.text('Collections'));
    expect(find.text('Alien Collection'), findsOneWidget);
    fail = true;
    await $.tester
        .widget<FlixieRefresh>(find.byType(FlixieRefresh))
        .onRefresh();
    await $.pumpAndSettle();
    expect(find.text('Alien Collection'), findsOneWidget);
    expect(find.text('Couldn’t refresh results.'), findsOneWidget);
    fail = false;
    await tapSearch($, find.text('Try again'));
    expect(collectionReads, 3);
    expect(find.text('Couldn’t refresh results.'), findsNothing);
  });
  test('Search results keep movie show and person destinations', ($) async {
    useApiFixture(MockClient((r) async => searchResponse(
        r.url.path.contains('trending')
            ? []
            : mediaPage(
                type: switch (r.url.queryParameters['type']) {
                'tv' => 'tv',
                'person' => 'person',
                _ => 'movie'
              }))));
    final router = await openSearch($);
    await submitSearch($, 'Alien');
    await tapSearch(
        $,
        find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'Alien'));
    expect(find.text('destination /movies/348'), findsOneWidget);
    router.pop();
    await $.pumpAndSettle();
    await tapSearch($, find.text('Shows'));
    await tapSearch($, find.text('Alien: Earth', findRichText: true));
    expect(find.text('destination /shows/157239'), findsOneWidget);
    router.pop();
    await $.pumpAndSettle();
    await tapSearch($, find.text('People'));
    await tapSearch($, find.text('Casey Runtime', findRichText: true));
    expect(find.text('destination /people/990000001'), findsOneWidget);
  });
  test('Search focus and notifications preserve query without another request',
      ($) async {
    var reads = 0;
    useApiFixture(MockClient((r) async {
      if (r.url.path.contains('trending')) return searchResponse([]);
      reads++;
      return searchResponse(mediaPage());
    }));
    final auth = SearchAuth();
    await openSearch($, auth: auth, focus: true);
    expect(
        $.tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue);
    await submitSearch($, 'Alien');
    final resultsView =
        $.tester.widget<SearchResultsView>(find.byType(SearchResultsView));
    auth.notifyCount(7);
    await $.pumpAndSettle();
    expect(
        identical(resultsView,
            $.tester.widget<SearchResultsView>(find.byType(SearchResultsView))),
        isTrue,
        reason: 'Unread count changes must not rebuild search results');
    expect(find.text('7'), findsOneWidget);
    expect($.tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Alien');
    expect(reads, 1);
    await tapSearch($, find.byIcon(Icons.notifications_outlined));
    expect(find.text('destination /notifications'), findsOneWidget);
  });
  test('Search changing query rejects an old pending response', ($) async {
    final old = Completer<http.Response>();
    useApiFixture(MockClient((r) async {
      if (r.url.path.contains('trending')) return searchResponse([]);
      if (r.url.queryParameters['value'] == 'Old') return old.future;
      return searchResponse(mediaPage());
    }));
    await openSearch($);
    await $.tester.enterText(find.byType(TextField), 'Old');
    await $.tester.testTextInput.receiveAction(TextInputAction.search);
    await $.pump();
    await $.tester.tap(find.byType(TextField));
    await $.pump();
    await $.tester.enterText(find.byType(TextField), 'Alien');
    await $.tester.testTextInput.receiveAction(TextInputAction.search);
    old.complete(searchResponse({
      'results': [
        {'id': 999, 'title': 'Stale result'}
      ]
    }));
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();
    expect(find.text('Stale result', findRichText: true), findsNothing);
    expect(
        find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == 'Alien'),
        findsOneWidget);
  });
}
