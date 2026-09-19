const int maxFavouriteMovies = 10;
const int maxFavouriteShows = 10;

bool isActiveFavouriteShow(dynamic item) {
  if (item is! Map) return true;
  return item['removed'] != true;
}
