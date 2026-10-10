import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/models/show_list.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'show_service.dart';

/// Injectable access to the existing TV APIs; cache ownership stays in services.
class ShowDetailService {
  const ShowDetailService();
  Future<TvShow> summary(int id) => ShowService.getShowSummary(id);
  Future<TvShow> details(int id, String? viewer) => ShowService.getShowById(id,
      userId: viewer, includeFriendSummary: false, includeTrailers: false);
  Future<List<WatchProvider>> providers(int id, String region) =>
      ShowService.getShowWatchProviders(id, region);
  Future<TvShowCredits> credits(int id) => ShowService.getShowCredits(id);
  Future<List<Review>> reviews(int id, String? viewer) =>
      ShowService.getShowReviews(id, userId: viewer);
  Future<List<WatchProvider>> userProviders(String viewer) =>
      UserService.getUserWatchProviders(viewer);
  Future<Map<String, dynamic>?> rating(int id, String viewer) =>
      ShowService.getUserShowRating(id, viewer);
  Future<TvShowFriendSummary?> friends(int id) =>
      ShowService.getFriendSummary(id);
  Future<List<ShowList>> containingLists(String viewer, int id) async {
    final lists = await UserService.getShowLists(viewer);
    final containing = <ShowList>[];
    for (final list in lists) {
      final shows = await UserService.getShowListShows(viewer, list.id);
      if (shows.any((show) => show.id == id)) containing.add(list);
    }
    return containing;
  }
}
