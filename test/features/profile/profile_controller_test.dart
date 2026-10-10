import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/profile/data/profile_data_service.dart';
import 'package:flixie_app/features/profile/models/profile_section.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flixie_app/features/profile/presentation/controllers/review_reactions_controller.dart';
import '../movies/show_detail_controller_test.dart' show ShowAuth;

typedef ActivityPage = ({List<ActivityListItem> items, String? nextCursor});

class ProfileAuth extends ShowAuth {
  @override
  int activityVersion = 0;
  @override
  int unreadNotificationCount = 0;
  int refreshes = 0;
  @override
  Future<void> refreshUserData() async {
    refreshes++;
    activityVersion++;
    notifyListeners();
  }
}

ActivityListItem activityItem(String id) => ActivityListItem.fromJson({
      'id': id,
      'userId': 'viewer',
      'type': 'watched_movie',
      'movieId': 348,
      'createdAt': '2026-10-07T10:00:00Z',
      'movie': {'id': 348, 'title': 'Alien'},
    });
ContinueWatchingShow continuing(int id) =>
    ContinueWatchingShow.fromJson({'showId': id, 'name': 'Alien: Earth $id'});

class ProfileData extends ProfileDataService {
  final calls = <String>[];
  final activityGates = <String, Completer<ActivityPage>>{};
  final extraGates = <String, Completer<List<ContinueWatchingShow>>>{};
  final ratingsGates = <String, Completer<List<MovieRating>>>{};
  final statsGates = <String, Completer<MovieWrapped>>{};
  bool providersFail = false;
  String? cursor;
  final dismissed = <String>[];
  @override
  Future<ActivityPage> activity(String userId,
      {String filter = 'all', String? cursor}) async {
    final key = '$userId/$filter/${cursor ?? "first"}';
    calls.add('activity:$key');
    if (activityGates[key] != null) return activityGates[key]!.future;
    return (items: [activityItem(userId)], nextCursor: this.cursor);
  }

  @override
  Future<List<MovieRating>> ratings(String userId) async {
    calls.add('ratings:$userId');
    if (ratingsGates[userId] != null) return ratingsGates[userId]!.future;
    return [];
  }

  @override
  Future<List<ContinueWatchingShow>> continueWatching(String userId) async {
    calls.add('extras:$userId');
    if (extraGates[userId] != null) return extraGates[userId]!.future;
    return [continuing(userId == 'viewer' ? 1 : 2)];
  }

  @override
  Future<List<WatchProvider>> watchProviders(String userId) async {
    calls.add('providers:$userId');
    if (providersFail) throw StateError('offline');
    return [];
  }

  @override
  Future<List<Review>> reviews(String userId) async {
    calls.add('reviews:$userId');
    return [
      Review.fromJson({'id': 'r1', 'userId': userId}),
      Review.fromJson({'id': 'r2', 'userId': userId})
    ];
  }

  @override
  Future<MovieWrapped> wrapped(String userId, int year) async {
    calls.add('stats:$userId');
    if (statsGates[userId] != null) return statsGates[userId]!.future;
    return MovieWrapped.fromJson({'year': year});
  }

  @override
  Future<List<MovieList>> movieLists(String userId) async {
    calls.add('lists:$userId');
    return [];
  }

  @override
  Future<void> dismissContinueWatching(String userId, int showId) async {
    dismissed.add('$userId/$showId');
  }
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ProfileAuth auth;
  late ProfileData service;
  late ProfileController data;
  setUp(() {
    auth = ProfileAuth();
    service = ProfileData();
    data = ProfileController(auth: auth, service: service);
  });
  tearDown(() {
    data.dispose();
    auth.dispose();
  });
  test('Library loads its own data and Stats remains lazy and coalesced',
      () async {
    await data.loadAll();
    expect(
        service.calls
            .where((c) => c.startsWith('stats:') || c.startsWith('reviews:')),
        isEmpty);
    final gate = Completer<MovieWrapped>();
    service.statsGates['viewer'] = gate;
    data.selectTab(ProfileTab.stats);
    final first = data.loadStats();
    final second = data.loadStats();
    expect(service.calls.where((c) => c == 'stats:viewer'), hasLength(1));
    gate.complete(MovieWrapped.fromJson({'year': 2026}));
    await Future.wait([first, second]);
    data.selectTab(ProfileTab.library);
    data.selectTab(ProfileTab.stats);
    await flush();
    expect(service.calls.where((c) => c == 'stats:viewer'), hasLength(1));
    expect(data.reviewCount, 2);
  });
  test('account changes clear content and reject old extras and ratings',
      () async {
    final extra = Completer<List<ContinueWatchingShow>>();
    final ratings = Completer<List<MovieRating>>();
    service.extraGates['viewer'] = extra;
    service.ratingsGates['viewer'] = ratings;
    final old = data.loadAll();
    final oldRatings = data.loadRatings();
    auth.select('other');
    await flush();
    expect(data.recentActivity.single.id, 'other');
    expect(data.activity, isEmpty);
    expect(data.continueWatching.single.showId, 2);
    extra.complete([continuing(99)]);
    ratings.complete([
      const MovieRating(
          id: 'old',
          userId: 'viewer',
          movieId: 348,
          rating: 9,
          createdAt: '',
          updatedAt: '')
    ]);
    await Future.wait([old, oldRatings]);
    expect(data.ratings, isEmpty);
    expect(data.continueWatching.single.showId, 2);
    auth.select(null);
    expect(data.activity, isEmpty);
    expect(data.continueWatching, isEmpty);
    expect(data.wrapped, isNull);
    expect(data.profileExtrasLoading, false);
    expect(data.activityRequestRunning, false);
  });
  test('filter change rejects pending old activity page', () async {
    final gate = Completer<ActivityPage>();
    service.activityGates['viewer/all/first'] = gate;
    final old = data.loadActivity();
    await data.selectFilter(ProfileActivityFilter.ratings);
    gate.complete((items: [activityItem('stale')], nextCursor: 'old'));
    await old;
    expect(data.activity.single.id, 'viewer');
    expect(data.activityFilter, ProfileActivityFilter.ratings);
    expect(data.activityCursor, isNull);
  });
  test(
      'pagination suppresses repeated taps and stale pages after filter change',
      () async {
    service.cursor = 'next';
    await data.loadActivity();
    final gate = Completer<ActivityPage>();
    service.activityGates['viewer/all/next'] = gate;
    final more = data.loadActivity(more: true);
    await data.loadActivity(more: true);
    expect(service.calls.where((c) => c == 'activity:viewer/all/next'),
        hasLength(1));
    await data.selectFilter(ProfileActivityFilter.reviews);
    gate.complete((items: [activityItem('stale')], nextCursor: null));
    await more;
    expect(data.activity.map((i) => i.id), ['viewer']);
    expect(data.activityRequestRunning, false);
  });
  test('ordinary notification updates do not reload data', () async {
    await data.loadAll();
    final before = List.of(service.calls);
    auth.unreadNotificationCount = 5;
    auth.notifyOnly();
    await flush();
    expect(service.calls, before);
  });
  test('manual refresh does not also trigger duplicate activity-version loads',
      () async {
    await data.loadAll();
    service.calls.clear();
    await data.refresh();
    expect(auth.refreshes, 1);
    expect(service.calls.where((c) => c.startsWith('activity:')), hasLength(1));
    expect(service.calls.where((c) => c.startsWith('ratings:')), isEmpty);
    expect(service.calls.where((c) => c.startsWith('lists:')), hasLength(1));
  });
  test(
      'a failed extras section retains content and does not discard the successful section',
      () async {
    await data.loadAll();
    service.providersFail = true;
    await data.loadProfileExtras();
    expect(data.continueWatching.single.showId, 1);
    expect(data.profileExtrasFailed, true);
    expect(data.profileExtrasLoading, false);
    service.providersFail = false;
    await data.loadProfileExtras();
    expect(data.profileExtrasFailed, false);
  });
  test('deleted reviews update the count without mutating a shared list',
      () async {
    await data.loadStats();
    final old = data.reviews;
    final deleted = ReviewReactionsController.deletedReviews.value;
    try {
      ReviewReactionsController.deletedReviews.value = {
        ...deleted,
        ReviewReactionsController.keyFor(data.reviews.first)
      };
      expect(data.reviewCount, 1);
      expect(data.reviews.single.id, 'r2');
      expect(old, hasLength(2));
    } finally {
      ReviewReactionsController.deletedReviews.value = deleted;
    }
  });
  test('disposed controller rejects a delayed activity response', () async {
    final gate = Completer<ActivityPage>();
    service.activityGates['viewer/all/first'] = gate;
    final pending = data.loadActivity();
    data.dispose();
    gate.complete((items: [activityItem('late')], nextCursor: null));
    await pending;
    expect(data.activity, isEmpty);
  });
  test('logout prevents pending Stats from restoring the previous viewer',
      () async {
    final gate = Completer<MovieWrapped>();
    service.statsGates['viewer'] = gate;
    final pending = data.loadStats();
    auth.select(null);
    gate.complete(MovieWrapped.fromJson({'year': 2026}));
    await pending;
    expect(data.wrapped, isNull);
    expect(data.reviews, isEmpty);
    expect(data.statsLoading, false);
  });
  test(
      'Library only fetches watches and visible extras; Activity and ratings load on demand',
      () async {
    await data.loadAll();
    expect(service.calls,
        ['activity:viewer/watches/first', 'extras:viewer', 'providers:viewer']);
    expect(data.recentActivity, isNotEmpty);
    expect(data.activity, isEmpty);
    data.selectTab(ProfileTab.activity);
    await flush();
    expect(service.calls.where((c) => c == 'activity:viewer/all/first'),
        hasLength(1));
    data.selectTab(ProfileTab.library);
    data.selectTab(ProfileTab.activity);
    await flush();
    expect(service.calls.where((c) => c == 'activity:viewer/all/first'),
        hasLength(1));
    await data.selectFilter(ProfileActivityFilter.reviews);
    expect(data.recentActivity.single.id, 'viewer');
    await Future.wait([data.loadRatings(), data.loadRatings()]);
    expect(service.calls.where((c) => c == 'ratings:viewer'), hasLength(1));
  });

  test(
      'Stats waits for ratings and does not refetch when delayed Library extras finish',
      () async {
    final extras = Completer<List<ContinueWatchingShow>>();
    final ratings = Completer<List<MovieRating>>();
    service.extraGates['viewer'] = extras;
    service.ratingsGates['viewer'] = ratings;
    final library = data.loadAll();
    data.selectTab(ProfileTab.stats);
    await flush();
    expect(data.wrapped, isNull);
    ratings.complete([]);
    await flush();
    expect(data.wrapped, isNotNull);
    extras.complete([]);
    await library;
    expect(service.calls.where((c) => c == 'stats:viewer'), hasLength(1));
    expect(service.calls.where((c) => c == 'ratings:viewer'), hasLength(1));
  });

  test(
      'activity change refreshes Library and invalidates hidden Activity and Stats',
      () async {
    await data.loadAll();
    data.selectTab(ProfileTab.activity);
    await flush();
    data.selectTab(ProfileTab.library);
    service.calls.clear();
    auth.activityVersion++;
    auth.notifyOnly();
    await flush();
    expect(service.calls, ['activity:viewer/watches/first']);
    data.selectTab(ProfileTab.activity);
    await flush();
    expect(service.calls.where((c) => c == 'activity:viewer/all/first'),
        hasLength(1));
  });
}
