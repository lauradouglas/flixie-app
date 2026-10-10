import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/data/person_service.dart';
import 'user_service.dart';

/// Injectable access to existing profile services; adds no cache.
class ProfileDataService {
  const ProfileDataService();
  Future<({List<ActivityListItem> items, String? nextCursor})> activity(
          String userId,
          {String filter = 'all',
          String? cursor}) =>
      UserService.getUserActivityPage(userId, filter: filter, cursor: cursor);
  Future<List<MovieRating>> ratings(String userId) =>
      UserService.getUserMovieRatings(userId);
  Future<List<ContinueWatchingShow>> continueWatching(String userId) =>
      ShowService.getContinueWatching(userId);
  Future<List<WatchProvider>> watchProviders(String userId) =>
      UserService.getUserWatchProviders(userId);
  Future<List<Review>> reviews(String userId) =>
      UserService.getUserReviews(userId);
  Future<MovieWrapped> wrapped(String userId, int year) =>
      UserService.getMovieWrapped(userId, year);
  Future<Person> person(int id) => PersonService.getPersonById(id);
  Future<List<MovieList>> movieLists(String userId) =>
      UserService.getMovieLists(userId);
  Future<void> dismissContinueWatching(String userId, int showId) =>
      ShowService.dismissContinueWatching(userId, showId);
}
