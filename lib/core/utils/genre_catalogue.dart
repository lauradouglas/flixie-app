/// Shared presentation catalogue. TV Movie is a format, not a browse genre.
bool isVisibleGenre(String name, {int? id}) =>
    id != 10770 &&
    !const {'tv movie', 'tv movies', 'tv film', 'tv films'}
        .contains(name.trim().toLowerCase());

int? genreIconId(String name) => const <String, int>{
      'anime': -1,
      'action': 28,
      'adventure': 12,
      'action & adventure': 28,
      'animation': 16,
      'comedy': 35,
      'crime': 80,
      'documentary': 99,
      'drama': 18,
      'family': 10751,
      'kids': 10751,
      'fantasy': 14,
      'history': 36,
      'horror': 27,
      'music': 10402,
      'mystery': 9648,
      'romance': 10749,
      'science fiction': 878,
      'sci-fi': 878,
      'sci fi': 878,
      'sci-fi & fantasy': 878,
      'thriller': 53,
      'war': 10752,
      'war & politics': 10752,
      'western': 37,
    }[name.trim().toLowerCase()];
