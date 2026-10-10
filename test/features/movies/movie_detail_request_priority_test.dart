import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_detail_controller.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/models/friend_summary.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../../movie_detail_loading_test.dart' show DelayedMovies;
import 'show_detail_controller_test.dart' show ShowAuth, flush;

class FriendsMovies extends DelayedMovies {
  int activityReads = 0, summaryReads = 0, unusedReads = 0;
  @override
  Future<List<MovieFriendActivity>> getFriendsMovieActivity(
      int id, String userId) async {
    activityReads++;
    return [];
  }

  @override
  Future<FriendSummaryResponse> getFriendSummary(int id) async {
    summaryReads++;
    return const FriendSummaryResponse(
        friendCount: 0, watchedCount: 0, favouriteCount: 0, watchlistCount: 0);
  }

  @override
  Future<FriendRecommendationResponse> getFriendRecommendation(int id) async {
    unusedReads++;
    throw StateError('Unused recommendation must not be fetched');
  }

  @override
  Future<({int? rating, bool? recommended})> getUserMovieRating(
          int id, String viewer) async =>
      (rating: null, recommended: null);
}

class DetailActions extends WatchlistActionsController {
  @override
  Future<List<MovieWatchEntry>> getMovieWatchHistory(
          String viewer, int id) async =>
      [];
  @override
  Future<List<MovieList>> getMyListsContainingMovie(
          String viewer, int id) async =>
      [];
  @override
  Future<List<MovieFriendListEntry>> getFriendsListsContainingMovie(
          String viewer, int id) async =>
      [];
  @override
  Future<List<WatchProvider>> getUserWatchProviders(String viewer) async => [];
}

void main() {
  test(
      'friends start with core; hidden work warms after core; no unused friend read',
      () async {
    final auth = ShowAuth();
    final service = FriendsMovies();
    service.providers.complete([]);
    service.reviews.complete([]);
    final controller = MovieDetailController(
        auth: auth, service: service, actions: DetailActions());
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    final load = controller.load('348');
    await flush();
    expect(service.activityReads, 1);
    expect(service.summaryReads, 1);
    expect(service.unusedReads, 0);
    expect(service.reviewCalls, 0);
    expect(service.imageCalls, 0);
    service.core[348]!.complete(const Movie(id: 348, title: 'Alien'));
    await load;
    expect(controller.movie!.title, 'Alien');
    expect(service.reviewCalls, 1);
    expect(service.imageCalls, 1);
    expect(service.unusedReads, 0);
    expect(controller.friendSummaryLoading, false);
  });
}
