import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart';

abstract class ProfileRepository {
  Future<List<ActivityListItem>> getUserActivity(String userId);
  Future<List<MovieRating>> getUserMovieRatings(String userId);
  Future<List<Review>> getUserMovieReviews(String userId);
  Future<User> getUserById(String userId);
  Future<User> getUserByUsername(String username);
  Future<List<User>> searchUsers(String query);
}
