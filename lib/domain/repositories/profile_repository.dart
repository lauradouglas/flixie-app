import '../../models/activity_list_item.dart';
import '../../models/movie_rating.dart';
import '../../models/review.dart';
import '../../models/user.dart';

abstract class ProfileRepository {
  Future<List<ActivityListItem>> getUserActivity(String userId);
  Future<List<MovieRating>> getUserMovieRatings(String userId);
  Future<List<Review>> getUserMovieReviews(String userId);
  Future<User> getUserById(String userId);
  Future<User> getUserByUsername(String username);
  Future<List<User>> searchUsers(String query);
}
