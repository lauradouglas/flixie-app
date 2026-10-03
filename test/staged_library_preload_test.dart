import 'dart:async';
import 'dart:convert';
import 'package:flixie_app/core/storage/library_image_warmup.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flutter/widgets.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';

void main() {
  tearDown(() {
    ApiClient.useClientForTesting(null);
    ShowService.clearSummaryCache();
  });

  test('poster warming is bounded and excludes removed titles', () {
    final user = User.fromJson({
      'id': 'fixture',
      'movieWatchlist': [
        {
          'movieId': 99,
          'removed': true,
          'movie': {'id': 99, 'title': 'Removed', 'posterPath': '/removed.jpg'}
        },
        for (var id = 1; id <= 400; id++)
          {
            'movieId': id,
            'movie': {'id': id, 'title': 'Film $id', 'posterPath': '/$id.jpg'}
          },
      ],
      'showWatchlist': [
        for (var id = 1; id <= 20; id++)
          {
            'showId': id,
            'show': {'id': id, 'name': 'Show $id', 'posterPath': '/show$id.jpg'}
          },
      ],
    });
    final urls = libraryPosterWarmupUrls(user);
    expect(urls, hasLength(6));
    expect(urls.any((url) => url.contains('removed')), false);
    expect(urls.last, endsWith('/show2.jpg'));
  });

  testWidgets(
      'plan warming waits for first frame and ignores switched accounts',
      (tester) async {
    final paths = <String>[];
    ApiClient.useClientForTesting(MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
          request.url.path.startsWith('/groups/') ? '{"groups":[]}' : '[]',
          200);
    }));
    final cache = WatchRequestCache();
    addTearDown(cache.dispose);
    cache.syncUser('old', deferWarm: true);
    cache.syncUser('new', deferWarm: true);
    expect(paths, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(paths, hasLength(2));
    expect(paths.any((path) => path.contains('old')), false);
  });

  test('startup warms notifications without history or streaming fan-out',
      () async {
    final paths = <String>[];
    ApiClient.useClientForTesting(MockClient((request) async {
      paths.add(request.url.path);
      return http.Response('[]', 200);
    }));
    final snapshot = await AuthPrefetchCoordinator(movieService: MovieService())
        .prefetch('fixture',
            watchlistMovieIds: List.generate(400, (i) => i + 1));
    expect(paths, ['/notifications/user/fixture']);
    expect(snapshot.unreadNotificationCount, 0);
    expect(snapshot.reviews, isNull);
    expect(snapshot.activity, isNull);
  });

  test('watchlist shares in-flight preload and reuses its completed summaries',
      () async {
    final response = Completer<http.Response>();
    var calls = 0;
    ApiClient.useClientForTesting(MockClient((request) {
      calls++;
      expect(request.url.path, '/shows/by-ids');
      return response.future;
    }));
    final warm = ShowService.warmLibrarySummaries([
      {'showId': 1399},
      {'showId': 1399},
      {'showId': 9, 'removed': true}
    ]);
    final opened = ShowService.getShowsByIds([1399]);
    response.complete(http.Response(
        jsonEncode([
          {'id': 1399, 'name': 'Fixture show'}
        ]),
        200));
    await warm;
    expect((await opened).single.name, 'Fixture show');
    expect((await ShowService.getShowsByIds([1399])).single.id, 1399);
    expect(calls, 1);
  });

  test('failed warming stays retryable and reset rejects old responses',
      () async {
    var calls = 0;
    final delayed = Completer<http.Response>();
    ApiClient.useClientForTesting(MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('unavailable', 503);
      return delayed.future;
    }));
    expect(await ShowService.getShowsByIds([1]), isEmpty);
    final retry = ShowService.getShowsByIds([1]);
    ShowService.clearSummaryCache();
    delayed.complete(http.Response('[{"id":1,"name":"Old response"}]', 200));
    expect(await retry, isEmpty);
    expect(ShowService.cachedSummary(1), isNull);
    expect(calls, 2);
  });
}
