import '../../domain/repositories/profile_repository.dart';
import '../../models/activity_list_item.dart';
import '../../models/movie_rating.dart';
import '../../models/review.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  @override
  Future<List<ActivityListItem>> getUserActivity(String userId) => UserService.getUserActivity(userId);

  @override
  Future<List<MovieRating>> getUserMovieRatings(String userId) => UserService.getUserMovieRatings(userId);

  @override
  Future<List<Review>> getUserMovieReviews(String userId) => UserService.getUserMovieReviews(userId);

  @override
  Future<User> getUserById(String userId) => UserService.getUserById(userId);

  @override
  Future<User> getUserByUsername(String username) => UserService.getUserByUsername(username);

  @override
  Future<List<User>> searchUsers(String query) => UserService.searchUsers(query);
}
