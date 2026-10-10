import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/controllers/friend_profile_controller.dart';
import 'package:flixie_app/features/profile/data/friend_profile_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'profile_controller_test.dart' show ProfileAuth;

User friendUser(String id) => User.fromJson({
      'id': id,
      'username': id,
      'email': '',
      'iconColorId': 0,
      'completedSetup': true
    });

class FriendData extends FriendProfileService {
  final users = <String, Completer<User?>>{};
  final pages =
      <Completer<({List<ActivityListItem> items, String? nextCursor})>>[];
  final reviewGates = <Completer<List<Review>>>[];
  final ratingValues = <String, List<MovieRating>>{};
  final userValues = <String, User?>{};
  int activityCalls = 0, reviewCalls = 0, friendCalls = 0, ratingCalls = 0;
  bool gatedPages = false, gatedReviews = false;
  bool unavailable = false, failedReviews = false;
  @override
  Future<User?> user(String id) =>
      users[id]?.future ??
      Future.value(unavailable ? null : userValues[id] ?? friendUser(id));
  @override
  Future<List<Review>> reviews(String id) {
    reviewCalls++;
    if (failedReviews) return Future.error(StateError('offline'));
    if (gatedReviews) {
      final c = Completer<List<Review>>();
      reviewGates.add(c);
      return c.future;
    }
    return Future.value([]);
  }

  @override
  Future<({List<ActivityListItem> items, String? nextCursor})> activity(
      String id,
      {String? cursor}) {
    activityCalls++;
    if (gatedPages) {
      final c =
          Completer<({List<ActivityListItem> items, String? nextCursor})>();
      pages.add(c);
      return c.future;
    }
    return Future.value((items: <ActivityListItem>[], nextCursor: null));
  }

  @override
  Future<List<MovieRating>> ratings(String id) {
    ratingCalls++;
    return Future.value(ratingValues[id] ?? []);
  }

  @override
  Future<FriendsData> friends(String id) {
    friendCalls++;
    return Future.value(FriendsData.fromJson(
        {'friendships': [], 'pendingFriends': [], 'requestedFriends': []}));
  }
}

Future<void> tick() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
      'compatibility preserves rating agreement and double-weighted active favourites',
      () async {
    final auth = ProfileAuth(), data = FriendData();
    MovieRating rating(String user, int id, int score) => MovieRating(
        id: '$user-$id',
        userId: user,
        movieId: id,
        rating: score,
        createdAt: '',
        updatedAt: '');
    FavoriteMovie fav(String user, int id, {bool removed = false}) =>
        FavoriteMovie(
            id: '$user-$id', userId: user, movieId: id, removed: removed);
    auth.account = auth.account!.copyWith(
        favoriteMovies: [fav('viewer', 1), fav('viewer', 2, removed: true)]);
    data.userValues['friend'] = friendUser('friend')
        .copyWith(favoriteMovies: [fav('friend', 1), fav('friend', 2)]);
    data.ratingValues['viewer'] = [
      rating('viewer', 1, 8),
      rating('viewer', 2, 10)
    ];
    data.ratingValues['friend'] = [
      rating('friend', 1, 6),
      rating('friend', 2, 10),
      rating('friend', 3, 7)
    ];
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    await c.loadAll();
    expect(c.sharedMovieCount, 2);
    expect(c.sharedFavCount, 1);
    expect(c.compatibilityScore, 94);
    expect(c.sharedRatings.map((r) => r.movieId), [1, 2]);
    expect(() => c.sharedRatings.clear(), throwsUnsupportedError);
  });

  test('switching viewed person rejects the old user and resets section state',
      () async {
    final auth = ProfileAuth(), data = FriendData();
    data.users['old'] = Completer<User?>();
    final c =
        FriendProfileController(auth: auth, subjectId: 'old', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    final old = c.loadAll();
    c.change(() => c.selectedTab = 2);
    c.setSubject('new');
    await tick();
    expect(c.user?.id, 'new');
    expect(c.selectedTab, 0);
    data.users['old']!.complete(friendUser('old'));
    await old;
    expect(c.user?.id, 'new');
    expect(data.reviewCalls, 1);
  });
  test('viewer change clears old private rows and invalidates pending reviews',
      () async {
    final auth = ProfileAuth(), data = FriendData()..gatedReviews = true;
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    final first = c.loadAll();
    await tick();
    auth.account = null;
    auth.notifyListeners();
    await tick();
    expect(c.reviews, isEmpty);
    expect(c.friendshipStatus, FriendshipStatus.none);
    expect(c.actionLoading, false);
    data.reviewGates[0].complete([]);
    data.reviewGates[1].complete([]);
    await first;
    await tick();
    expect(c.reviews, isEmpty);
  });
  test('refresh rejects old pagination and suppresses double more taps',
      () async {
    final auth = ProfileAuth(), data = FriendData()..gatedPages = true;
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    final initial = c.loadAll();
    await tick();
    data.pages[0].complete((items: <ActivityListItem>[], nextCursor: 'next'));
    await initial;
    final more = c.loadActivity(more: true);
    await c.loadActivity(more: true);
    expect(data.activityCalls, 2);
    final refresh = c.loadAll();
    await tick();
    data.pages[2].complete((items: <ActivityListItem>[], nextCursor: 'fresh'));
    await refresh;
    data.pages[1].complete((items: <ActivityListItem>[], nextCursor: 'stale'));
    await more;
    expect(c.activityCursor, 'fresh');
    expect(c.activityLoading, false);
  });
  test('notification-only updates do not refetch other profile', () async {
    final auth = ProfileAuth(), data = FriendData();
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    await c.loadAll();
    final calls = [
      data.reviewCalls,
      data.activityCalls,
      data.friendCalls,
      data.ratingCalls
    ];
    auth.notifyListeners();
    await tick();
    expect([
      data.reviewCalls,
      data.activityCalls,
      data.friendCalls,
      data.ratingCalls
    ], calls);
  });
  test('unavailable profile does not start other private sections', () async {
    final auth = ProfileAuth(), data = FriendData()..unavailable = true;
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    await c.loadAll();
    expect(c.user, null);
    expect(data.activityCalls, 0);
    expect(data.reviewCalls, 0);
    expect(data.ratingCalls, 0);
    expect(c.userLoading, false);
  });
  test('failed reviews expose retry and successful retry clears error',
      () async {
    final auth = ProfileAuth(), data = FriendData()..failedReviews = true;
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    await c.loadAll();
    expect(c.reviewsFailed, true);
    expect(c.reviewsLoading, false);
    data.failedReviews = false;
    await c.loadReviews();
    expect(c.reviewsFailed, false);
  });
  test('disposed pending profile cannot publish or start its sections',
      () async {
    final auth = ProfileAuth(), data = FriendData();
    data.users['friend'] = Completer<User?>();
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(auth.dispose);
    final pending = c.loadAll();
    c.dispose();
    data.users['friend']!.complete(friendUser('friend'));
    await pending;
    expect(c.user, null);
    expect(data.reviewCalls, 0);
  });
}
