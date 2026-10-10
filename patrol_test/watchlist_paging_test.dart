import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_movie_row.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../test/support/api_fixture.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import '../test/support/watchlist_auth.dart';

void main() {
  patrolTest('400-title watchlist fetches more friends and providers on scroll', ($) async {
    final auth = TestAuth()..ids = List.generate(400, (i) => i + 1);
    addTearDown(auth.dispose);
    final requested = <int>{};
    final client = MockClient((request) async {
      if (request.url.path == '/movies/friend-recommendations') {
        final ids = (jsonDecode(request.body)['movieIds'] as List).cast<int>();
        requested.addAll(ids);
        return http.Response(jsonEncode({'items': [for (final id in ids) {
          'movieId': '$id', 'recommendPercent': 0, 'friendCount': 0,
          'recommendedCount': 0, 'friends': []
        }]}), 200, headers: {'content-type': 'application/json'});
      }
      expect(request.url.path, '/users/viewer/watch-providers');
      return http.Response('{"watchProviders":[]}', 200,
          headers: {'content-type': 'application/json'});
    });
    useApiFixture(client);
    await $.pumpWidgetAndSettle(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const WatchlistScreen())));
    await $(find.byWidgetPredicate((widget) => widget is WatchlistMovieRow &&
        widget.watchlistItem.movieId == 1 && !widget.isLoadingFriends &&
        !widget.friendsFailed)).waitUntilVisible();
    expect(requested.length, 20);
    expect(auth.providerRequests.single.length, 20);
    await $.tester.scrollUntilVisible(find.text('Film 21'), 500,
        scrollable: find.descendant(of: find.byKey(const ValueKey('watchlist-cards')),
            matching: find.byType(Scrollable)).first, maxScrolls: 60);
    await $.pumpAndSettle();
    await $(find.byWidgetPredicate((widget) => widget is WatchlistMovieRow &&
        widget.watchlistItem.movieId == 21 && !widget.isLoadingFriends &&
        !widget.friendsFailed)).waitUntilVisible();
    expect(requested, contains(21));
    expect(requested.length, inInclusiveRange(40, 60));
    expect(auth.providerRequests.every((batch) => batch.length <= 20), isTrue);
    expect($.tester.takeException(), isNull);
    await $.pumpWidgetAndSettle(const SizedBox.shrink());
  });
}
