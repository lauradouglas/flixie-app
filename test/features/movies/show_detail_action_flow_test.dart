import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/movies/presentation/controllers/show_detail_controller.dart';
import 'package:flixie_app/features/movies/presentation/show_detail_action_flow.dart';
import 'show_detail_controller_test.dart';
import 'movie_detail_action_flow_test.dart' show ActionAnalytics;

void main() {
  late ShowAuth auth;
  late ShowData service;
  late ShowDetailController data;
  late ShowDetailActionFlow flow;
  final requests = <http.Request>[];
  Completer<http.Response>? gate;
  bool failSecond = false;
  setUp(() async {
    requests.clear();
    gate = null;
    failSecond = false;
    auth = ShowAuth();
    service = ShowData();
    data = ShowDetailController(auth: auth, service: service);
    final client = MockClient((request) async {
      requests.add(request);
      if (gate != null) return gate!.future;
      if (failSecond && request.url.path.contains('/episodes/2/')) {
        return http.Response('{"message":"offline"}', 503);
      }
      return http.Response(
          jsonEncode({'voteAverage': 8.5, 'voteCount': 4}), 200);
    });
    ApiClient.useClientForTesting(client);
    final loading = data.load('1');
    service.ready(1, 'viewer');
    await loading;
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      client.close();
      data.dispose();
      auth.dispose();
    });
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AnalyticsController>(
              create: (_) => ActionAnalytics())
        ],
        child: MaterialApp(home: Scaffold(body: Builder(builder: (context) {
          flow = ShowDetailActionFlow(context: context, data: data);
          return const SizedBox();
        })))));
  }

  testWidgets('watchlist remains usable at favourites capacity',
      (tester) async {
    auth.account = auth.account!
        .copyWith(favoriteShows: List.generate(10, (i) => {'showId': i + 20}));
    await mount(tester);
    await flow.toggleWatchlist(offerUndo: false);
    await tester.pump();
    expect(requests.length, 1);
    expect(data.inWatchlist, true);
    expect(auth.account!.showWatchlist!.length, 1);
    expect(auth.changes, 1);
    expect(find.text('Added to watchlist'), findsOneWidget);
  });
  testWidgets('favourites limit is checked before attempting a favourite save',
      (tester) async {
    auth.account = auth.account!
        .copyWith(favoriteShows: List.generate(10, (i) => {'showId': i + 20}));
    await mount(tester);
    await flow.toggleFavorite();
    await tester.pump();
    expect(requests, isEmpty);
    expect(data.isFavorite, false);
    expect(find.textContaining('10'), findsWidgets);
  });
  testWidgets(
      'late save cannot update a different account or show a success toast',
      (tester) async {
    await mount(tester);
    gate = Completer();
    final pending = flow.toggleWatchlist();
    await tester.pump();
    auth.select('other');
    gate!.complete(http.Response('{}', 200));
    await pending;
    await tester.pump();
    expect(auth.updates, 0);
    expect(data.inWatchlist, false);
    expect(find.text('Added to watchlist'), findsNothing);
    service.full['1:other']!.complete(const TvShow(id: 1, name: 'Other'));
    await tester.pump();
  });
  testWidgets('episode save updates progress and Undo restores original date',
      (tester) async {
    final oldDate = DateTime.utc(2026, 9, 1);
    final episode = TvEpisode(
        id: 1,
        seasonNumber: 1,
        episodeNumber: 1,
        name: 'Pilot',
        watched: true,
        watchedAt: oldDate);
    data.show = TvShow(id: 1, name: 'Alien: Earth', episodes: [episode]);
    await mount(tester);
    await flow.setEpisodeWatched(episode, false);
    await tester.pump();
    expect(data.show!.episodes.single.watched, false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(data.show!.episodes.single.watched, true);
    expect(data.show!.episodes.single.watchedAt, oldDate);
    expect(
        jsonDecode(requests.last.body)['watchedAt'], oldDate.toIso8601String());
  });
  testWidgets(
      'season partial failure keeps successful subset and Undo only changes it',
      (tester) async {
    final episodes = [
      const TvEpisode(id: 1, seasonNumber: 1, episodeNumber: 1, name: 'Pilot'),
      const TvEpisode(id: 2, seasonNumber: 1, episodeNumber: 2, name: 'Second')
    ];
    data.show = TvShow(id: 1, name: 'Alien: Earth', episodes: episodes);
    failSecond = true;
    await mount(tester);
    await flow.applySeasonProgress('viewer', 1, 1, episodes, true);
    await tester.pump();
    expect(data.show!.episodes.first.watched, true);
    expect(data.show!.episodes.last.watched, false);
    final before = requests.length;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests.length, before + 1);
    expect(data.show!.episodes.first.watched, false);
    expect(data.show!.episodes.last.watched, false);
  });
  testWidgets(
      'catch up preserves watched history and excludes selected episode with Undo',
      (tester) async {
    final oldDate = DateTime.utc(2026, 1, 1);
    final episodes = List.generate(
        5,
        (i) => TvEpisode(
            id: i + 1,
            seasonNumber: 1,
            episodeNumber: i + 1,
            name: 'Episode ${i + 1}',
            airDate: '2020-01-01',
            watched: i == 0,
            watchedAt: i == 0 ? oldDate : null));
    data.show = TvShow(id: 1, name: 'The OA', episodes: episodes);
    await mount(tester);
    await flow.catchUpToEpisode(episodes.last, includeSelected: false);
    await tester.pump();
    expect(requests.length, 3);
    expect(data.show!.episodes.take(4).every((e) => e.watched), true);
    expect(data.show!.episodes.last.watched, false);
    expect(data.show!.episodes.first.watchedAt, oldDate);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(data.show!.episodes.where((e) => e.watched).length, 1);
    expect(data.show!.episodes.first.watchedAt, oldDate);
  });

  testWidgets('duplicate episode saves coalesce by busy state', (tester) async {
    const episode =
        TvEpisode(id: 1, seasonNumber: 1, episodeNumber: 1, name: 'Pilot');
    data.show = const TvShow(id: 1, name: 'Alien', episodes: [episode]);
    await mount(tester);
    gate = Completer();
    final pending = flow.setEpisodeWatched(episode, true);
    await tester.pump();
    await flow.setEpisodeWatched(episode, true);
    expect(requests.length, 1);
    gate!.complete(http.Response('{}', 200));
    await pending;
    expect(data.updatingEpisodeIds, isEmpty);
  });
  testWidgets('rating response preserves episode runtime and progress metadata',
      (tester) async {
    const episode = TvEpisode(
        id: 1, seasonNumber: 1, episodeNumber: 1, name: 'Pilot', watched: true);
    data.show = const TvShow(
        id: 1, name: 'Alien: Earth', episodeRuntime: 50, episodes: [episode]);
    await mount(tester);
    await flow.setUserRating(9, offerUndo: false);
    await tester.pump();
    expect(data.userRating, 9);
    expect(data.show!.voteAverage, 8.5);
    expect(data.show!.episodeRuntime, 50);
    expect(data.show!.episodes.single.watched, true);
  });
}
