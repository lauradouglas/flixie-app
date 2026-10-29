import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/curated_lists/data/curated_lists_service.dart';
import 'package:flixie_app/features/curated_lists/models/curated_list.dart';
import 'package:flixie_app/features/pip/data/pip_collection_service.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'package:flixie_app/features/profile/data/diary_entry_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/user.dart';

const fixtureId = 'ac040000-0000-4000-a000-000000000001';
CuratedList fixtureList({int? target = 1}) => CuratedList(
        id: fixtureId,
        theme: CuratedListTheme.christmas,
        title: 'Did someone say Christmas?',
        description: 'A few festive favourites, picked by Flixie.',
        filmCount: 2,
        completionTarget: target,
        startsAt: DateTime.now().subtract(const Duration(days: 1)),
        endsAt: DateTime.now().add(const Duration(days: 1)),
        films: const [
          CuratedFilm(id: 71, title: 'Elf', releaseDate: '2003-11-07'),
          CuratedFilm(id: 72, title: 'Home Alone', releaseDate: '1990-11-16')
        ],
        rewards: const [
          CuratedReward(
              type: 'PIP', key: 'christmasLights', name: 'Christmas Pip'),
          CuratedReward(
              type: 'AVATAR_BORDER',
              key: 'christmasLightsSnow',
              name: 'Lights and snow border')
        ]);

class CuratedFixtureService extends CuratedListsService {
  CuratedList value = fixtureList();
  bool joined = false, failProgress = false, done = false;
  final Set<int> watched = {};
  int joins = 0, reconciles = 0;
  Completer<CuratedList>? pendingDetail;
  Completer<CuratedProgress>? pendingProgress;
  @override
  Future<CuratedList> detail(String id) {
    final gate = pendingDetail;
    pendingDetail = null;
    return gate?.future ?? Future.value(value);
  }

  @override
  Future<List<CuratedList>> lists(
          {bool homepage = false, int page = 1}) async =>
      page == 1 ? [value] : [];
  @override
  Future<void> join(String id) async {
    joins++;
    joined = true;
  }

  CuratedProgress snapshot() => CuratedProgress(
      watched: watched.length,
      required: value.requiredCount,
      total: value.filmCount,
      joined: joined,
      completedAt: done ? DateTime(2026, 12, 1) : null,
      watchedIds: Set.of(watched));
  @override
  Future<CuratedProgress> progress(String id) {
    final gate = pendingProgress;
    pendingProgress = null;
    if (failProgress) throw StateError('offline');
    return gate?.future ?? Future.value(snapshot());
  }

  @override
  Future<CuratedProgress> reconcile(String id) async {
    reconciles++;
    if (failProgress) throw StateError('offline');
    if (joined && watched.length >= value.requiredCount) done = true;
    return snapshot();
  }
}

class CuratedFixtureAuth extends ChangeNotifier implements AuthProvider {
  User? account = const User(
      id: 'curated-viewer',
      username: 'Casey',
      email: 'casey@example.invalid',
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  User? get dbUser => account;
  @override
  int activityVersion = 0;
  @override
  void markActivityChanged() {
    activityVersion++;
    notifyListeners();
  }

  @override
  Future<void> refreshUserData() async {
    if (account != null) {
      account = account!.copyWith(profileBadges: [
        ...account!.profileBadges,
        'BORDER_CHRISTMAS_LIGHTS'
      ]);
    }
    notifyListeners();
  }

  @override
  Future<bool> refreshLibrary() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class CuratedFixtureDiary extends DiaryEntryService {
  CuratedFixtureDiary(this.lists);
  final CuratedFixtureService lists;
  final List<LogMovieWatchRequest> writes = [];
  @override
  Future<MovieWatchEntry> log(
      String userId, LogMovieWatchRequest request) async {
    writes.add(request);
    if (request.rating != null) lists.watched.add(request.movieId);
    return MovieWatchEntry(
        id: 'watch-${writes.length}',
        userId: userId,
        movieId: request.movieId,
        watchedAt: request.watchedAt,
        removed: false);
  }
}

class CuratedFixturePips extends PipCollectionService {
  CuratedFixturePips(this.lists);
  final CuratedFixtureService lists;
  String active = 'classic';
  final List<Map<String, dynamic>> writes = [];
  @override
  Future<PipCollection> load() async => PipCollection(
      activePip: active,
      unlockedPips:
          lists.done ? const [UnlockedPip('christmasLights')] : const []);
  @override
  Future<PipCollection> update(Map<String, dynamic> body) async {
    writes.add(body);
    if (body['activePip'] != null) active = body['activePip'] as String;
    return load();
  }
}
