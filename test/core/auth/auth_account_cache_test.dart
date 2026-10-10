import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/auth_account_cache.dart';
import 'package:flixie_app/core/auth/auth_prefetch_coordinator.dart';
import 'package:flixie_app/core/auth/auth_prefetch_snapshot.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/watch_provider.dart';

typedef Providers = ({
  Map<int, List<WatchProvider>> providersByMovieId,
  Set<int> userProviderIds
});

class ProviderLoader implements AuthPrefetchCoordinator {
  final calls = <({String user, String region, Set<int> movies})>[];
  final pending = <Completer<Providers>>[];
  final progress = <void Function(Map<int, List<WatchProvider>>, Set<int>)?>[];
  @override
  Future<Providers> fetchWatchProviders(
    String userId,
    Iterable<int> movieIds, {
    required String region,
    bool Function()? isCurrent,
    void Function(Map<int, List<WatchProvider>>, Set<int>)? onProgress,
  }) {
    calls.add((user: userId, region: region, movies: movieIds.toSet()));
    final completion = Completer<Providers>();
    pending.add(completion);
    progress.add(onProgress);
    return completion.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

FlixieNotification notice(String id, {String user = 'robin'}) =>
    FlixieNotification(
        id: id,
        userId: user,
        type: FlixieNotification.friendRequest,
        message: 'Fixture',
        read: false);

void main() {
  test(
      'partial inbox pages preserve the server unread total during local mutations',
      () {
    final cache = AuthAccountCache(ProviderLoader());
    cache.updateCachedNotifications([notice('first')],
        userId: 'robin', unreadCount: 100);
    expect(cache.unreadNotificationCount, 100);
    cache.removeCachedNotification('first', userId: 'robin');
    expect(cache.unreadNotificationCount, 99);
    cache.clear();
    expect(cache.unreadNotificationCount, 0);
  });

  test(
      'friend badge changes invalidate identity while unchanged snapshots reuse the version',
      () {
    final cache = AuthAccountCache(ProviderLoader());
    FriendsData friends(List<String> badges) => FriendsData(friendships: [
          Friendship(
              id: 'friendship',
              friendId: 'sam',
              createdAt: '',
              updatedAt: '',
              friend: FriendshipUser(
                  id: 'sam', username: 'sam', profileBadges: badges))
        ], pendingFriends: const [], requestedFriends: const []);
    cache.applyPrefetchSnapshot(
        AuthPrefetchSnapshot(friends: friends(['EARLY_SUPPORTER'])));
    final initial = cache.friendDataVersion;
    cache.applyPrefetchSnapshot(
        AuthPrefetchSnapshot(friends: friends(['EARLY_SUPPORTER'])));
    expect(cache.friendDataVersion, initial);
    cache.applyPrefetchSnapshot(
        AuthPrefetchSnapshot(friends: friends(['FIRST_REVIEW'])));
    expect(cache.friendDataVersion, initial + 1);
    expect(cache.cachedFriends!.friendships.single.friend!.profileBadges,
        ['FIRST_REVIEW']);
  });

  test(
      'dismissed cards cannot reappear through prefetch; clear resets the next account',
      () {
    final cache = AuthAccountCache(ProviderLoader());
    cache.updateCachedNotifications(
        [notice('one'), notice('foreign', user: 'sam')],
        userId: 'robin');
    expect(cache.cachedNotifications!.map((n) => n.id), ['one']);
    cache.removeCachedNotification('one', userId: 'robin');
    cache.applyPrefetchSnapshot(
        AuthPrefetchSnapshot(notifications: [notice('one')]));
    expect(cache.cachedNotifications, isEmpty);
    expect(cache.unreadNotificationCount, 0);
    cache.clear();
    cache
        .updateCachedNotifications([notice('one', user: 'sam')], userId: 'sam');
    expect(cache.cachedNotifications!.single.userId, 'sam');
    expect(cache.unreadNotificationCount, 1);
  });

  test(
      'partial refresh preserves loaded sections; activity invalidates only its dependent data',
      () {
    final cache = AuthAccountCache(ProviderLoader());
    cache.applyPrefetchSnapshot(const AuthPrefetchSnapshot(
        activity: [],
        friendsActivity: [],
        ratings: [],
        reviews: [],
        trending: [MovieShort(id: 348, name: 'Alien')],
        nowPlaying: [],
        groups: [],
        movieLists: [],
        watchRequests: []));
    cache.applyPrefetchSnapshot(const AuthPrefetchSnapshot(reviews: []));
    expect(cache.cachedTrending!.single.id, 348);
    cache.invalidateActivity();
    expect(cache.cachedActivity, isNull);
    expect(cache.cachedFriendsActivity, isNull);
    expect(cache.cachedRatings, isNull);
    expect(cache.cachedReviews, isNotNull);
    expect(cache.cachedTrending, isNotNull);
    cache.clear();
    expect([
      cache.cachedActivity,
      cache.cachedFriendsActivity,
      cache.cachedFriends,
      cache.cachedGroups,
      cache.cachedRatings,
      cache.cachedReviews,
      cache.cachedTrending,
      cache.cachedNowPlaying,
      cache.cachedMovieLists,
      cache.cachedNotifications,
      cache.cachedWatchRequests,
      cache.cachedUserWatchProviderIds
    ], everyElement(isNull));
    expect(cache.cachedWatchProvidersByMovieId, isEmpty);
  });

  test(
      'overlapping provider callers share work and request only missing titles',
      () async {
    final loader = ProviderLoader();
    final cache = AuthAccountCache(loader);
    Future<void> load(Set<int> movies) => cache.ensureWatchProviders(
        userId: 'robin',
        region: 'GB',
        movieIds: movies,
        isCurrent: () => true,
        onChanged: () {});
    final first = load({348});
    final second = load({348, 550});
    expect(loader.calls.length, 1);
    loader.pending[0].complete((
      providersByMovieId: <int, List<WatchProvider>>{348: []},
      userProviderIds: {8}
    ));
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(loader.calls[1].movies, {550});
    loader.pending[1].complete((
      providersByMovieId: <int, List<WatchProvider>>{550: []},
      userProviderIds: {8}
    ));
    await second;
    await load({348, 550});
    expect(loader.calls.length, 2);
    expect(cache.cachedWatchProvidersByMovieId.keys, containsAll([348, 550]));
  });

  test(
      'reset rejects old progress, result and queued requests without clearing new work',
      () async {
    final loader = ProviderLoader();
    final cache = AuthAccountCache(loader);
    var changes = 0;
    Future<void> load(String user, int movie) => cache.ensureWatchProviders(
        userId: user,
        region: 'GB',
        movieIds: [movie],
        isCurrent: () => true,
        onChanged: () => changes++);
    final old = load('robin', 348);
    final queued = load('robin', 550);
    cache.clear();
    final next = load('sam', 11);
    loader.progress[0]!({348: []}, {8});
    loader.pending[0].complete((
      providersByMovieId: <int, List<WatchProvider>>{348: []},
      userProviderIds: {8}
    ));
    await Future.wait([old, queued]);
    expect(changes, 0);
    expect(loader.calls.length, 2);
    expect(cache.cachedWatchProvidersByMovieId, isEmpty);
    final shared = load('sam', 11);
    expect(loader.calls.length, 2,
        reason: 'old completion must not clear new single-flight work');
    loader.pending[1].complete((
      providersByMovieId: <int, List<WatchProvider>>{11: []},
      userProviderIds: {9}
    ));
    await Future.wait([next, shared]);
    expect(cache.cachedWatchProvidersByMovieId.keys, [11]);
    expect(cache.cachedUserWatchProviderIds, {9});
  });

  test('region changes reject old availability and fetch fresh preferences',
      () async {
    final loader = ProviderLoader();
    final cache = AuthAccountCache(loader);
    Future<void> load(String region) => cache.ensureWatchProviders(
        userId: 'robin',
        region: region,
        movieIds: [348],
        isCurrent: () => true,
        onChanged: () {});
    final gb = load('GB');
    final us = load('US');
    loader.pending[0].complete((
      providersByMovieId: <int, List<WatchProvider>>{348: []},
      userProviderIds: {8}
    ));
    await gb;
    await Future<void>.delayed(Duration.zero);
    expect(cache.cachedWatchProvidersByMovieId, isEmpty);
    expect(loader.calls[1].region, 'US');
    loader.pending[1].complete((
      providersByMovieId: <int, List<WatchProvider>>{348: []},
      userProviderIds: {9}
    ));
    await us;
    expect(cache.cachedUserWatchProviderIds, {9});
  });
}
