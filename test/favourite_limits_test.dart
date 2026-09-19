import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/user.dart';

void main() {
  test('removed movies are not treated as current favourites', () {
    const user = User(
      id: 'user-1',
      externalId: 'external-1',
      username: 'flixie',
      email: 'flixie@example.com',
      iconColorId: 1,
      completedSetup: true,
      darkMode: true,
      favoriteMovies: [
        FavoriteMovie(
          id: 'favourite-1',
          userId: 'user-1',
          movieId: 42,
          removed: true,
        ),
      ],
    );

    expect(user.isMovieFavorite(42), isFalse);
  });

  test('favourite limits and active show filtering stay consistent', () {
    expect(maxFavouriteMovies, 10);
    expect(maxFavouriteShows, 10);
    expect(isActiveFavouriteShow({'showId': 1, 'removed': false}), isTrue);
    expect(isActiveFavouriteShow({'showId': 2, 'removed': true}), isFalse);
  });

  test('recognises server favourite-limit failures', () {
    expect(
      isFavouriteLimitError(
        Exception('You can favourite up to 10 movies and 10 shows'),
      ),
      isTrue,
    );
    expect(isFavouriteLimitError(Exception('Network unavailable')), isFalse);
  });
}
