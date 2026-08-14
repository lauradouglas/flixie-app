const int maxFavouriteMovies = 25;
const int maxFavouriteShows = 25;

bool isActiveFavouriteShow(dynamic item) {
  if (item is! Map) return true;
  return item['removed'] != true;
}
