import '../repositories/profile_repository.dart';
import '../../models/activity_list_item.dart';
import '../../models/movie_rating.dart';
import '../../models/review.dart';
import '../../models/user.dart';

class ProfileLookupUseCase {
  ProfileLookupUseCase(this._profileRepository);

  final ProfileRepository _profileRepository;

  Future<List<ActivityListItem>> getUserActivity(String userId) => _profileRepository.getUserActivity(userId);
  Future<List<MovieRating>> getUserMovieRatings(String userId) => _profileRepository.getUserMovieRatings(userId);
  Future<List<Review>> getUserMovieReviews(String userId) => _profileRepository.getUserMovieReviews(userId);
  Future<User> getUserById(String userId) => _profileRepository.getUserById(userId);
  Future<User> getUserByUsername(String username) => _profileRepository.getUserByUsername(username);
  Future<List<User>> searchUsers(String query) => _profileRepository.searchUsers(query);
}
