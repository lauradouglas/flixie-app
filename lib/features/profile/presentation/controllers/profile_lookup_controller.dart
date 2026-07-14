import 'package:flixie_app/features/profile/data/profile_repository_impl.dart';
import 'package:flixie_app/features/profile/data/profile_lookup_usecase.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart';

class ProfileLookupController {
  ProfileLookupController({ProfileLookupUseCase? useCase}) : _useCase = useCase ?? ProfileLookupUseCase(ProfileRepositoryImpl());

  static final ProfileLookupController instance = ProfileLookupController();

  final ProfileLookupUseCase _useCase;

  Future<List<ActivityListItem>> getUserActivity(String userId) => _useCase.getUserActivity(userId);
  Future<List<MovieRating>> getUserMovieRatings(String userId) => _useCase.getUserMovieRatings(userId);
  Future<List<Review>> getUserMovieReviews(String userId) => _useCase.getUserMovieReviews(userId);
  Future<User> getUserById(String userId) => _useCase.getUserById(userId);
  Future<User> getUserByUsername(String username) => _useCase.getUserByUsername(username);
  Future<List<User>> searchUsers(String query) => _useCase.searchUsers(query);
}
