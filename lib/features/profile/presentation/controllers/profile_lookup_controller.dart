import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/watch_provider.dart';

class ProfileLookupController {
  const ProfileLookupController();

  static const ProfileLookupController instance = ProfileLookupController();

  Future<List<ActivityListItem>> getUserActivity(String userId) =>
      UserService.getUserActivity(userId);
  Future<List<MovieRating>> getUserMovieRatings(String userId) =>
      UserService.getUserMovieRatings(userId);
  Future<List<Review>> getUserMovieReviews(String userId) =>
      UserService.getUserMovieReviews(userId);
  Future<List<MovieList>> getMovieLists(String userId) =>
      UserService.getMovieLists(userId);
  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      UserService.getUserWatchProviders(userId);
  Future<User> getUserById(String userId) => UserService.getUserById(userId);
  Future<User> getUserByUsername(String username) =>
      UserService.getUserByUsername(username);
  Future<List<User>> searchUsers(String query) =>
      UserService.searchUsers(query);
}
