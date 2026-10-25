import '../../authentication/data/setup_service.dart';
import '../../movies/data/movie_service.dart';
import '../../home/data/recommendation_service.dart';
import '../../profile/data/user_service.dart';

class TasteService {
  const TasteService();
  Future<List<SetupTitle>> titles(String query) => query.trim().isEmpty
      ? const SetupService()
          .popular(false)
          .then((rows) => rows.take(6).toList())
      : const SetupService()
          .search(query.trim(), false)
          .then((rows) => rows.take(18).toList());
  Future<Set<int>> favourites(String id) async =>
      (await UserService.getUserById(id))
          .favoriteMovies
          ?.where((f) => f.removed != true)
          .map((f) => f.movieId)
          .toSet() ??
      {};
  Future<void> favourite(String id, SetupTitle title, bool add) => add
      ? const SetupService().addProfileFavourite(id, title)
      : UserService.removeFromFavorites(id, title.id);
  Future<({int? rating, bool? recommended})> rating(String id, int movie) =>
      MovieService().getUserMovieRating(movie, id);
  Future<void> rate(
      String id, int movie, int score, String? recommendation) async {
    await MovieService().addMovieRating(
        movie,
        id,
        score,
        recommendation == null || recommendation == 'neutral'
            ? null
            : recommendation == 'recommend');
  }

  void invalidate(String id) =>
      RecommendationService.invalidateCache(userId: id);
}
