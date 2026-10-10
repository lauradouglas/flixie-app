import 'package:flixie_app/features/watchlist/models/watchlist_filters.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/watchlist/data/watchlist_data_service.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_controller.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import '../../support/watchlist_auth.dart';

class FixtureAuth extends TestAuth {
  String owner = 'fixture-robin';

  @override
  User get dbUser => super.dbUser.copyWith(
        id: owner,
        movieWatchlist: ids.map((id) {
          final title = switch (id) {
            1 => 'The Odyssey',
            2 => 'Alien',
            3 => 'Spider-Man',
            _ => 'Fixture film $id',
          };
          return WatchlistMovie(
            id: '$owner-$id',
            userId: owner,
            movieId: id,
            movie: WatchlistMovieDetails(
                id: id,
                title: title,
                runtime: id == 2 ? 117 : 160,
                genres: const ['Science Fiction'],
                releaseDate: '2020-01-01'),
          );
        }).toList(),
      );
}

class FixtureData extends WatchlistDataService {
  final requests = <List<int>>[];
  Completer<void>? gate;

  @override
  Future<List<WatchProvider>> getSavedProviders(String userId) async => [];

  @override
  Future<Map<int, FriendRecommendationResponse>> getMovieFriends(
    Iterable<int> ids, {
    required bool Function() isCurrent,
    required void Function(Map<int, FriendRecommendationResponse>) onProgress,
  }) async {
    final batch = ids.toList();
    requests.add(batch);
    await gate?.future;
    final result = {
      for (final id in batch)
        id: const FriendRecommendationResponse(
          recommendPercent: 100,
          friendCount: 1,
          recommendedCount: 1,
          friends: [
            FriendRecommendationItem(
                userId: 'fixture-sam',
                username: 'Sam',
                recommends: true,
                profileBadges: ['founder'])
          ],
        ),
    };
    // Deliberately publish even when cancelled: the controller must reject it.
    onProgress(result);
    return result;
  }

  @override
  Future<Map<int, FriendRecommendationResponse>> getShowFriends(
    Iterable<int> ids, {
    required bool Function() isCurrent,
    required void Function(Map<int, FriendRecommendationResponse>) onProgress,
  }) async =>
      {};
}

Future<void> drain() => Future<void>.delayed(Duration.zero);

void main() {
  group('Watchlist controller', () {
    late FixtureAuth auth;
    late FixtureData data;
    late WatchlistController controller;
    late List<VoidCallback> frames;

    setUp(() {
      auth = FixtureAuth()..ids = [1, 2, 3];
      data = FixtureData();
      frames = [];
      controller = WatchlistController(
          auth: auth, service: data, scheduleAfterFrame: frames.add)
        ..loadWatchlist();
    });
    tearDown(() {
      controller.dispose();
      auth.dispose();
    });

    test('search, time and clear project the library without making requests',
        () {
      controller.setSearchQuery('ALI');
      expect(
          controller.visibleItems
              .whereType<WatchlistMovie>()
              .map((item) => item.movieId),
          [2]);
      controller.setSearchQuery('');
      controller.updateFilters((filters) => filters.maxRuntime = 120);
      expect(
          controller.visibleItems
              .whereType<WatchlistMovie>()
              .map((item) => item.movieId),
          [2]);
      controller.clearFilters();
      expect(controller.visibleItems, hasLength(3));
      expect(data.requests, isEmpty);
      expect(controller.allWatchlist, hasLength(3));
    });

    test('filter snapshots and library collections cannot mutate owned state',
        () {
      final snapshot = controller.filters;
      snapshot.media = 2;
      snapshot.avoid.add('violence');
      expect(controller.filters.media, 0);
      expect(controller.filters.avoid, isEmpty);
      expect(() => controller.allWatchlist.clear(), throwsUnsupportedError);
      expect(
          () => controller.movieWatchProviders.clear(), throwsUnsupportedError);
      WatchlistFilters? draft;
      controller.updateFilters((filters) {
        draft = filters;
        filters.sort = 'titleAsc';
      });
      draft!.media = 2;
      expect(controller.filters.media, 0);
      expect(
          controller.visibleItems
              .whereType<WatchlistMovie>()
              .map((item) => item.movie!.title),
          ['Alien', 'Spider-Man', 'The Odyssey']);
    });

    test('queued work from a previous viewer never starts', () async {
      controller.prepareEnrichment(controller.visibleItems);
      auth.owner = 'fixture-jules';
      auth.ids = [2];
      controller.onUserChanged();
      for (final frame in List.of(frames)) {
        frame();
      }
      await drain();
      expect(data.requests, isEmpty);
      expect(auth.providerRequests, isEmpty);
      expect(controller.allWatchlist.single.userId, 'fixture-jules');
    });

    test('late friend responses cannot repaint a newly selected account',
        () async {
      data.gate = Completer<void>();
      controller.prepareEnrichment(controller.visibleItems);
      frames.removeAt(0)();
      await drain();
      expect(data.requests.single, [1, 2, 3]);
      auth.owner = 'fixture-jules';
      auth.ids = [2];
      controller.onUserChanged();
      data.gate!.complete();
      await drain();
      expect(controller.recommendationsByMovieId, isEmpty);
      expect(controller.completedEnrichment, isEmpty);
      expect(controller.allWatchlist.single.userId, 'fixture-jules');
    });

    test('duplicate visible pages share bounded enrichment work', () async {
      auth.ids = List.generate(45, (index) => index + 1);
      controller.loadWatchlist();
      final items = controller.visibleItems;
      controller.scheduleEnrichment(items);
      controller.scheduleEnrichment(items);
      expect(frames, hasLength(1));
      frames.removeAt(0)();
      await drain();
      expect(data.requests.map((batch) => batch.length), [20, 20, 5]);
      expect(data.requests.expand((batch) => batch).toSet(), hasLength(45));
      expect(controller.completedEnrichment, hasLength(45));
      expect(controller.recommendationsByMovieId[1]!.single.profileBadges,
          ['founder']);
    });

    test('disposing during a request discards progress without notifying',
        () async {
      data.gate = Completer<void>();
      controller.prepareEnrichment(controller.visibleItems);
      frames.removeAt(0)();
      await drain();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      data.gate!.complete();
      await drain();
      expect(notifications, 0);
      expect(controller.recommendationsByMovieId, isEmpty);
      // The group teardown disposes its replacement rather than the old owner.
      controller = WatchlistController(
          auth: auth, service: data, scheduleAfterFrame: frames.add);
    });
  });
}
