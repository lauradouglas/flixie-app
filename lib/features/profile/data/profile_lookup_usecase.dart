import 'package:flixie_app/features/profile/data/profile_repository.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/watch_provider.dart';

class ProfileLookupUseCase {
  ProfileLookupUseCase(this._profileRepository);

  final ProfileRepository _profileRepository;

  Future<List<ActivityListItem>> getUserActivity(String userId) =>
      _profileRepository.getUserActivity(userId);
  Future<List<MovieRating>> getUserMovieRatings(String userId) =>
      _profileRepository.getUserMovieRatings(userId);
  Future<List<Review>> getUserMovieReviews(String userId) =>
      _profileRepository.getUserMovieReviews(userId);
  Future<List<MovieList>> getMovieLists(String userId) =>
      _profileRepository.getMovieLists(userId);
  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      _profileRepository.getUserWatchProviders(userId);
  Future<User> getUserById(String userId) =>
      _profileRepository.getUserById(userId);
  Future<User> getUserByUsername(String username) =>
      _profileRepository.getUserByUsername(username);
  Future<List<User>> searchUsers(String query) =>
      _profileRepository.searchUsers(query);
}
