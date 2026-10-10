import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';

/// Injectable access metadata boundary using the existing list API.
class MovieListDetailService {
  const MovieListDetailService();
  Future<MovieListMembership> members(String ownerId, String listId) =>
      UserService.getMovieListMembers(ownerId, listId);
  Future<User> owner(String ownerId) => UserService.getUserById(ownerId);
}
