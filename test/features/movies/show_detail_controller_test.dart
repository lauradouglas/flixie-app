import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/show_list.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/movies/data/show_detail_service.dart';
import 'package:flixie_app/features/movies/presentation/controllers/show_detail_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

class ShowAuth extends ChangeNotifier implements AuthProvider {
  int changes = 0, updates = 0;
  void notifyOnly() => notifyListeners();
  @override
  void markActivityChanged() => changes++;
  @override
  void updateUserList(
      {List<WatchedMovie>? watchedMovies,
      List<dynamic>? watchedShows,
      List<WatchlistMovie>? movieWatchlist,
      List<dynamic>? showWatchlist,
      List<FavoriteMovie>? favoriteMovies,
      List<dynamic>? favoriteShows,
      List<dynamic>? favoritePeople}) {
    updates++;
    account = account!.copyWith(
        showWatchlist: showWatchlist ?? account!.showWatchlist,
        favoriteShows: favoriteShows ?? account!.favoriteShows);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
  User? account = const User(
      id: 'viewer',
      username: 'Fixture',
      email: '',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  User? get dbUser => account;
  void select(String? id) {
    account = id == null
        ? null
        : User(
            id: id,
            username: 'Fixture',
            email: '',
            iconColorId: 0,
            completedSetup: true,
            darkMode: true);
    notifyListeners();
  }
}

class ShowData extends ShowDetailService {
  final summaries = <int, Completer<TvShow>>{};
  final full = <String, Completer<TvShow>>{};
  final calls = <String, int>{};
  bool creditsFail = false, listsFail = false;
  Completer<List<ShowList>>? listsGate;
  void call(String name) => calls.update(name, (n) => n + 1, ifAbsent: () => 1);
  @override
  Future<TvShow> summary(int id) {
    call('summary');
    return summaries.putIfAbsent(id, () => Completer()).future;
  }

  @override
  Future<TvShow> details(int id, String? viewer) {
    call('details');
    return full.putIfAbsent('$id:$viewer', () => Completer()).future;
  }

  @override
  Future<TvShowCredits> credits(int id) async {
    call('cast');
    if (creditsFail) throw StateError('offline');
    return const TvShowCredits(cast: [], crew: []);
  }

  @override
  Future<List<WatchProvider>> providers(int id, String region) async {
    call('providers');
    return [];
  }

  @override
  Future<List<Review>> reviews(int id, String? viewer) async {
    call('reviews');
    return [];
  }

  @override
  Future<List<WatchProvider>> userProviders(String viewer) async => [];
  @override
  Future<Map<String, dynamic>?> rating(int id, String viewer) async =>
      {'rating': 8};
  @override
  Future<TvShowFriendSummary?> friends(int id) async {
    call('friends');
    return null;
  }

  @override
  Future<List<ShowList>> containingLists(String viewer, int id) async {
    if (listsFail) throw const ApiException(statusCode: 403, message: 'denied');
    if (listsGate != null) return listsGate!.future;
    return [];
  }

  void ready(int id, String viewer, {String name = 'Alien: Earth'}) {
    summaries
        .putIfAbsent(id, () => Completer())
        .complete(TvShow(id: id, name: 'Summary $name'));
    full
        .putIfAbsent('$id:$viewer', () => Completer())
        .complete(TvShow(id: id, name: name));
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  late ShowAuth auth;
  late ShowData service;
  late ShowDetailController data;
  setUp(() {
    auth = ShowAuth();
    service = ShowData();
    data = ShowDetailController(auth: auth, service: service);
  });
  tearDown(() {
    data.dispose();
    auth.dispose();
  });
  test(
      'summary is useful while full detail is pending; late summary cannot overwrite full',
      () async {
    final loading = data.load('1');
    expect(service.calls['friends'], 1);
    expect(service.calls['reviews'], isNull);
    service.summaries[1]!.complete(const TvShow(id: 1, name: 'Useful summary'));
    await flush();
    expect(data.show!.name, 'Useful summary');
    expect(service.calls['reviews'], 1);
    expect(data.isLoading, false);
    expect(data.detailsLoading, true);
    service.full['1:viewer']!
        .complete(const TvShow(id: 1, name: 'Full detail'));
    await loading;
    expect(data.show!.name, 'Full detail');
    expect(data.detailsLoading, false);
  });
  test('full detail wins when summary arrives later', () async {
    final loading = data.load('1');
    service.full['1:viewer']!.complete(const TvShow(id: 1, name: 'Full'));
    await flush();
    expect(service.calls['reviews'], 1);
    service.summaries[1]!.complete(const TvShow(id: 1, name: 'Old'));
    await loading;
    expect(data.show!.name, 'Full');
    expect(service.calls['reviews'], 1);
  });
  test('section retry fetches only failed cast and clears the error', () async {
    service.creditsFail = true;
    final loading = data.load('1');
    service.ready(1, 'viewer');
    await loading;
    expect(data.detailErrors, contains('cast'));
    final before = Map.of(service.calls);
    service.creditsFail = false;
    await data.retrySection('cast');
    expect(data.detailErrors, isNot(contains('cast')));
    expect(service.calls['cast'], before['cast']! + 1);
    expect(service.calls['summary'], before['summary']);
    expect(service.calls['details'], before['details']);
  });
  test('account changes clear private state and ignore older responses',
      () async {
    final old = data.load('1');
    await flush();
    expect(data.userRating, 8);
    auth.select('other');
    expect(data.userRating, isNull);
    expect(data.show, isNull);
    service.summaries[1]!.complete(const TvShow(id: 1, name: 'Public'));
    service.full['1:viewer']!
        .complete(const TvShow(id: 1, name: 'Private old'));
    await old;
    await flush();
    expect(data.show?.name, isNot('Private old'));
    service.full['1:other']!
        .complete(const TvShow(id: 1, name: 'Other viewer'));
    await flush();
    expect(data.show!.name, 'Other viewer');
  });
  test('different show and disposal reject late work', () async {
    final old = data.load('1');
    final next = data.load('2');
    service.ready(2, 'viewer', name: 'New');
    await next;
    service.ready(1, 'viewer', name: 'Old');
    await old;
    expect(data.show!.id, 2);
    final pending = data.load('3');
    data.dispose();
    service.ready(3, 'viewer');
    await pending;
    expect(data.show, isNull);
  });
  test(
      'overlapping list refresh and account changes cannot publish stale lists',
      () async {
    final loading = data.load('1');
    service.ready(1, 'viewer');
    await loading;
    await flush();
    final gate = Completer<List<ShowList>>();
    service.listsGate = gate;
    final pending = data.loadListsContainingShow('viewer', 1);
    auth.select(null);
    gate.complete([]);
    await pending;
    expect(data.myListsContainingShow, isEmpty);
    expect(data.listsContainingShowLoading, false);
    expect(data.userRating, isNull);
  });
  test('ordinary auth notifications do not reload TV detail', () async {
    final loading = data.load('1');
    service.ready(1, 'viewer');
    await loading;
    final calls = Map.of(service.calls);
    auth.notifyOnly();
    await flush();
    expect(service.calls, calls);
  });
  test('invalid ID ends loading without API work', () async {
    await data.load('nope');
    expect(data.error, 'Invalid show ID.');
    expect(data.isLoading, false);
    expect(service.calls, isEmpty);
  });
}
