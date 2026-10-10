import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'recommendation_service.dart';
import 'trending_service.dart';

/// Home's data dependencies. Existing services retain their caches/coalescing.
class HomeDataService {
  const HomeDataService();
  Future<List<MovieShort>> trending({bool refresh = false}) =>
      TrendingService.getTrendingMovies(refresh: refresh);
  Future<List<MovieShort>> recommendations(String userId,
          {bool refresh = false}) =>
      RecommendationService.getUserRecommendations(userId, refresh: refresh);
  Future<List<WatchlistMovie>> watchlist(String userId) =>
      UserService.getUserWatchlist(userId);
  Future<List<ContinueWatchingShow>> continueWatching(String userId) =>
      ShowService.getContinueWatching(userId);
  Future<List<FriendMediaInteraction>> friends(String userId, int movieId) =>
      FriendService.getFriendsMovieInteractions(userId, movieId);
}
