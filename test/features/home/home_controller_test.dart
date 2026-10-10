import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/home/data/home_data_service.dart';
import 'package:flixie_app/features/home/presentation/controllers/home_controller.dart';
import 'package:flixie_app/features/home/presentation/controllers/home_watch_plans_controller.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/user.dart';

const alien = MovieShort(id: 13, name: 'Alien');
const odyssey = MovieShort(id: 14, name: 'The Odyssey');
User viewer(String id) => User(
    id: id,
    username: id,
    email: '$id@example.invalid',
    iconColorId: 0,
    completedSetup: true,
    darkMode: true);
Future<void> flush() => Future<void>.delayed(Duration.zero);

class SessionAuth extends ChangeNotifier implements AuthProvider {
  User? user = viewer('first');
  int profiles = 0;
  @override
  User? get dbUser => user;
  @override
  int activityVersion = 0;
  @override
  bool activityIncludesRefreshedProfile = false;
  void select(User? value) {
    user = value;
    notifyListeners();
  }

  void activity({bool refreshed = false}) {
    activityIncludesRefreshedProfile = refreshed;
    activityVersion++;
    notifyListeners();
  }

  @override
  Future<void> refreshUserData() async {
    profiles++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Plans extends HomeWatchPlansController {
  Plans(super.cache);
  final loads = <bool>[];
  @override
  Future<void> load(User? user, {bool force = true}) async {
    loads.add(force);
  }
}

class Data extends HomeDataService {
  final calls = <String>[];
  Future<List<MovieShort>> Function(bool)? trendingRequest;
  Future<List<MovieShort>> Function(String, bool)? recommendationRequest;
  Future<List<FriendMediaInteraction>> Function(String, int)? friendRequest;
  @override
  Future<List<MovieShort>> trending({bool refresh = false}) {
    calls.add('trending:$refresh');
    return trendingRequest?.call(refresh) ?? Future.value([alien]);
  }

  @override
  Future<List<MovieShort>> recommendations(String id, {bool refresh = false}) {
    calls.add('recommendations:$id:$refresh');
    return recommendationRequest?.call(id, refresh) ?? Future.value([odyssey]);
  }

  @override
  Future<List<ContinueWatchingShow>> continueWatching(String id) async {
    calls.add('continue:$id');
    return [];
  }

  @override
  Future<List<WatchlistMovie>> watchlist(String id) async {
    calls.add('watchlist:$id');
    return [];
  }

  @override
  Future<List<FriendMediaInteraction>> friends(String id, int movieId) {
    calls.add('friends:$id:$movieId');
    return friendRequest?.call(id, movieId) ?? Future.value([]);
  }
}

void main() {
  late SessionAuth auth;
  late Data data;
  late WatchRequestCache cache;
  late Plans plans;
  late HomeController home;
  setUp(() {
    HomeController.clearSessionSnapshotForTesting();
    auth = SessionAuth();
    data = Data();
    cache = WatchRequestCache();
    plans = Plans(cache);
    home = HomeController(auth: auth, watchPlans: plans, service: data);
  });
  tearDown(() {
    home.dispose();
    auth.dispose();
    cache.dispose();
  });

  for (final size in [0, 20, 400]) {
    test('fresh $size-title bootstrap avoids the duplicate watchlist request',
        () async {
      auth.user = viewer('first').copyWith(
          movieWatchlist: List.generate(
              size,
              (i) =>
                  WatchlistMovie(id: '$i', userId: 'first', movieId: i + 1)));
      auth.activityIncludesRefreshedProfile = true;
      await home.load();
      await flush();
      expect(data.calls.where((c) => c.startsWith('watchlist:')), isEmpty);
      expect(
          home.watchlist.value.data.ids, {for (var i = 1; i <= size; i++) i});
      await home.load(refreshRecommendations: true);
      await flush();
      expect(data.calls.where((c) => c.startsWith('watchlist:')),
          ['watchlist:first']);
      expect(home.watchlist.value.data.ids, isEmpty);
    });
  }

  test('bootstrap completion preserves an in-flight watchlist edit', () async {
    auth.activityIncludesRefreshedProfile = true;
    auth.user = viewer('first').copyWith(movieWatchlist: const []);
    final loading = home.load();
    home.setWatchlistMembership(13, true, pending: true);
    await loading;
    await flush();
    expect(home.watchlist.value.data.ids, {13});
    expect(home.watchlist.value.data.pending, {13});
    home.finishWatchlistUpdate(13);
    expect(home.watchlist.value.data.ids, {13});
    expect(home.watchlist.value.data.pending, isEmpty);
  });

  test('stale or omitted bootstrap membership uses the endpoint', () async {
    auth.user = viewer('first').copyWith(movieWatchlist: const []);
    await home.load();
    await flush();
    expect(data.calls, contains('watchlist:first'));
    auth.activityIncludesRefreshedProfile = true;
    auth.select(viewer('second'));
    await home.load();
    await flush();
    expect(data.calls, contains('watchlist:second'));
  });

  test('bootstrap is consumed once and account changes replace membership',
      () async {
    auth.activityIncludesRefreshedProfile = true;
    auth.user = viewer('first').copyWith(movieWatchlist: const [
      WatchlistMovie(id: '1', userId: 'first', movieId: 13),
      WatchlistMovie(id: '2', userId: 'first', movieId: 14, removed: true),
    ]);
    await home.load();
    await flush();
    expect(home.watchlist.value.data.ids, {13});
    await home.load();
    await flush();
    expect(data.calls.where((c) => c.startsWith('watchlist:')),
        ['watchlist:first']);
    auth.select(viewer('second').copyWith(movieWatchlist: const []));
    await home.load();
    await flush();
    expect(home.watchlist.value.data.ids, isEmpty);
    expect(data.calls, isNot(contains('watchlist:second')));
  });

  test(
      'initial carousel loads two cards, swipes fetch ahead and revisits reuse empty results',
      () async {
    data.trendingRequest = (_) async =>
        List.generate(12, (i) => MovieShort(id: i + 1, name: 'Movie ${i + 1}'));
    await home.load();
    await flush();
    List<String> reads() =>
        data.calls.where((c) => c.startsWith('friends:')).toList();
    expect(reads(), ['friends:first:1', 'friends:first:2']);
    await home.showHeroPage(1);
    expect(reads(), ['friends:first:1', 'friends:first:2', 'friends:first:3']);
    await home.showHeroPage(0);
    expect(reads(), hasLength(3));
    await home.showHeroPage(11);
    expect(reads().last, 'friends:first:12');
    expect(reads(), hasLength(4));
  });

  test(
      'rapid page changes coalesce pending reads and refresh invalidates old results',
      () async {
    data.trendingRequest = (_) async => [alien, odyssey];
    final pending = Completer<List<FriendMediaInteraction>>();
    data.friendRequest = (_, __) => pending.future;
    await home.load();
    final swipe = home.showHeroPage(1);
    expect(data.calls.where((c) => c.startsWith('friends:')), hasLength(2));
    data.friendRequest = (_, __) async => [];
    await home.load(refreshRecommendations: true);
    await flush();
    pending.complete([
      const FriendMediaInteraction(
          userId: 'old', username: 'Old', onWatchlist: true, favourited: false)
    ]);
    await swipe;
    expect(home.friendInteractions[odyssey.id], isEmpty);
    expect(data.calls.where((c) => c.startsWith('friends:')), hasLength(3));
    await home.showHeroPage(0);
    expect(data.calls.where((c) => c.startsWith('friends:')), hasLength(4));
  });

  test('failed visible activity can be retried without rereading its neighbour',
      () async {
    data.trendingRequest = (_) async => [alien, odyssey];
    data.friendRequest = (_, id) =>
        id == alien.id ? Future.error(StateError('offline')) : Future.value([]);
    await home.load();
    await flush();
    expect(home.friendActivity(alien.id).value.error, isNotNull);
    data.friendRequest = (_, __) async => [];
    await home.retryFriendActivity(alien);
    expect(home.friendActivityLoaded(alien.id), true);
    expect(home.friendActivity(alien.id).value.error, isNull);
    expect(data.calls.where((c) => c == 'friends:first:14'), hasLength(1));
  });

  test(
      'remount fetches first cards missing from a refreshed later-page snapshot',
      () async {
    data.trendingRequest = (_) async =>
        [alien, odyssey, const MovieShort(id: 15, name: 'Obsession')];
    await home.load();
    await home.showHeroPage(2);
    await home.load(refreshRecommendations: true);
    await flush();
    home.dispose();
    data.calls.clear();
    home = HomeController(auth: auth, watchPlans: Plans(cache), service: data);
    home.start();
    await flush();
    expect(data.calls, ['friends:first:13', 'friends:first:14']);
    expect(home.friendActivityLoaded(alien.id), true);
  });

  test('trending becomes usable while independent recommendations are pending',
      () async {
    final pending = Completer<List<MovieShort>>();
    data.recommendationRequest = (_, __) => pending.future;
    await home.load();
    expect(home.trending.value.data, [alien]);
    expect(home.trending.value.loading, false);
    expect(home.recommendations.value.loading, true);
    expect(home.continueWatching.value.loading, false);
    var trendingChanges = 0;
    home.trending.addListener(() => trendingChanges++);
    pending.complete([odyssey]);
    await flush();
    expect(home.recommendations.value.data, [odyssey]);
    expect(home.recommendations.value.loading, false);
    expect(trendingChanges, 0,
        reason: 'optional completion never notifies trending');
  });

  test('late full-load results cannot overwrite a newer refresh', () async {
    final oldTrending = Completer<List<MovieShort>>();
    final oldRecommendations = Completer<List<MovieShort>>();
    data.trendingRequest =
        (refresh) => refresh ? Future.value([odyssey]) : oldTrending.future;
    data.recommendationRequest = (_, refresh) =>
        refresh ? Future.value([alien]) : oldRecommendations.future;
    final old = home.load();
    await home.load(refreshRecommendations: true, showFullLoading: false);
    await flush();
    oldTrending.complete([alien]);
    oldRecommendations.complete([odyssey]);
    await old;
    await flush();
    expect(home.trending.value.data, [odyssey]);
    expect(home.recommendations.value.data, [alien]);
    expect(auth.profiles, 1);
  });

  test(
      'logout clears private sections and rejects same-account late results after relogin',
      () async {
    home.start();
    await flush();
    final pending = Completer<List<MovieShort>>();
    data.recommendationRequest = (_, __) => pending.future;
    await home.load();
    final oldSession = home.session;
    auth.select(null);
    expect(home.recommendations.value.data, isEmpty);
    expect(home.friendInteractions, isEmpty);
    expect(home.watchlist.value.data.ids, isEmpty);
    data.recommendationRequest = (_, __) async => [alien];
    auth.select(viewer('first'));
    await flush();
    pending.complete([odyssey]);
    await flush();
    expect(home.recommendations.value.data, [alien]);
    expect(home.ownsSession(oldSession), false);
  });

  test(
      'a different account never receives pending friend activity from the previous viewer',
      () async {
    final pending = Completer<List<FriendMediaInteraction>>();
    data.friendRequest =
        (id, _) => id == 'first' ? pending.future : Future.value([]);
    home.start();
    await flush();
    auth.select(viewer('second'));
    await flush();
    pending.complete([
      const FriendMediaInteraction(
          userId: 'private',
          username: 'Private',
          onWatchlist: true,
          favourited: false,
          profileBadges: ['EARLY_ADOPTER'])
    ]);
    await flush();
    expect(home.userId, 'second');
    expect(home.friendInteractions[alien.id], isEmpty);
  });

  test(
      'disposal ignores pending requests without notifying disposed section listeners',
      () async {
    final pending = Completer<List<MovieShort>>();
    data.trendingRequest = (_) => pending.future;
    final loading = home.load();
    var changes = 0;
    home.trending.addListener(() => changes++);
    home.dispose();
    pending.complete([alien]);
    await loading;
    await flush();
    expect(changes, 0);
  });

  test(
      'section failures retain content, while permission denial removes private picks',
      () async {
    await home.load();
    await flush();
    data.recommendationRequest = (_, __) => Future.error(StateError('offline'));
    await home.load(refreshRecommendations: true);
    await flush();
    expect(home.recommendations.value.data, [odyssey]);
    expect(home.recommendations.value.loading, false);
    expect(home.secondaryError.value, isNotNull);
    data.recommendationRequest = (_, __) => Future.error(const ApiException(
        statusCode: 403, code: 'FORBIDDEN', message: 'Denied'));
    await home.load(refreshRecommendations: true);
    await flush();
    expect(home.recommendations.value.data, isEmpty);
    data.recommendationRequest = (_, __) async => [alien];
    await home.load(refreshRecommendations: true);
    await flush();
    expect(home.recommendations.value.data, [alien]);
    expect(home.secondaryError.value, isNull);
  });

  test(
      'notification/profile-only signals do not reload Home; resume reuses its profile',
      () async {
    home.start();
    await flush();
    data.calls.clear();
    auth.select(viewer('first'));
    await flush();
    expect(data.calls, isEmpty);
    auth.activity(refreshed: true);
    await flush();
    expect(auth.profiles, 0);
    expect(data.calls, contains('recommendations:first:true'));
    auth.activity();
    await flush();
    expect(auth.profiles, 1,
        reason: 'action-driven refresh still reloads profile');
    await home.load(refreshRecommendations: true);
    await flush();
    expect(auth.profiles, 2, reason: 'manual refresh remains explicit');
  });

  test(
      'same-account remount restores useful data without reloading; another account does not',
      () async {
    await home.load();
    await flush();
    home.dispose();
    data.calls.clear();
    home = HomeController(auth: auth, watchPlans: Plans(cache), service: data);
    home.start();
    await flush();
    expect(home.trending.value.data, [alien]);
    expect(home.recommendations.value.data, [odyssey]);
    expect(data.calls, isEmpty);
    expect((home.watchPlans as Plans).loads, [false]);
    home.dispose();
    auth.select(viewer('second'));
    home = HomeController(auth: auth, watchPlans: Plans(cache), service: data);
    expect(home.trending.value.data, isEmpty);
    home.start();
    await flush();
    expect(data.calls, contains('recommendations:second:false'));
  });

  test('activity changed off-screen refreshes a restored snapshot exactly once',
      () async {
    await home.load();
    await flush();
    home.dispose();
    auth.activity(refreshed: true);
    data.calls.clear();
    home = HomeController(auth: auth, watchPlans: Plans(cache), service: data);
    expect(home.trending.value.data, [alien]);
    home.start();
    await flush();
    expect(data.calls.where((call) => call == 'recommendations:first:true'),
        hasLength(1));
    expect(auth.profiles, 0,
        reason: 'fresh resume profile remains reusable after remount');
  });

  test('a remount revalidates optional sections left pending on disposal',
      () async {
    final pending = Completer<List<MovieShort>>();
    data.recommendationRequest = (_, __) => pending.future;
    await home.load();
    home.dispose();
    data.recommendationRequest = (_, __) async => [alien];
    home = HomeController(auth: auth, watchPlans: Plans(cache), service: data);
    home.start();
    await flush();
    expect(home.recommendations.value.data, [alien]);
    pending.complete([odyssey]);
    await flush();
    expect(home.recommendations.value.data, [alien]);
  });

  test('friend replies notify only their own movie and preserve badge data',
      () async {
    data.trendingRequest = (_) async => [alien, odyssey];
    final first = Completer<List<FriendMediaInteraction>>();
    final second = Completer<List<FriendMediaInteraction>>();
    data.friendRequest =
        (_, id) => id == alien.id ? first.future : second.future;
    await home.load();
    var alienChanges = 0, odysseyChanges = 0;
    home.friendActivity(alien.id).addListener(() => alienChanges++);
    home.friendActivity(odyssey.id).addListener(() => odysseyChanges++);
    first.complete([
      const FriendMediaInteraction(
          userId: 'friend',
          username: 'Fictional',
          onWatchlist: true,
          favourited: false,
          profileBadges: ['EARLY_ADOPTER'])
    ]);
    await flush();
    expect(alienChanges, 1);
    expect(odysseyChanges, 0);
    expect(home.friendInteractions[alien.id]!.single.profileBadges,
        ['EARLY_ADOPTER']);
    second.complete([]);
    await flush();
    expect(alienChanges, 1);
    expect(odysseyChanges, 1);
  });

  test(
      'explicit recommendation failure ends loading without discarding earlier picks',
      () async {
    await home.load();
    await flush();
    data.recommendationRequest = (_, __) => Future.error(StateError('offline'));
    await expectLater(home.refreshRecommendations(), throwsStateError);
    expect(home.recommendations.value.loading, false);
    expect(home.recommendations.value.data, [odyssey]);
    expect(
        () => home.recommendations.value.data.clear(), throwsUnsupportedError);
  });
}
