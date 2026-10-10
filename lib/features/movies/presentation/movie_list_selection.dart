import 'package:flixie_app/models/movie_list_movie.dart';

enum MovieListSort { recentlyAdded, title, releaseYear, rating, addedBy }

List<MovieListMovie> sortedMovieList(
    List<MovieListMovie> movies, MovieListSort sort) {
  final sorted = List<MovieListMovie>.from(movies);
  switch (sort) {
    case MovieListSort.recentlyAdded:
      sorted.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      break;
    case MovieListSort.title:
      sorted.sort((a, b) => entryTitle(a).compareTo(entryTitle(b)));
      break;
    case MovieListSort.releaseYear:
      sorted.sort((a, b) => entryReleaseYear(b).compareTo(entryReleaseYear(a)));
      break;
    case MovieListSort.rating:
      sorted.sort(
          (a, b) => (entryRating(b) ?? -1).compareTo(entryRating(a) ?? -1));
      break;
    case MovieListSort.addedBy:
      sorted.sort((a, b) =>
          (a.addedBy?.username ?? '').compareTo(b.addedBy?.username ?? ''));
      break;
  }
  return sorted;
}

List<MovieListContributor> movieListContributors(
  List<MovieListMovie> movies,
) {
  final contributors = <String, MovieListContributor>{};
  for (final entry in movies) {
    final contributor = entry.addedBy;
    if (contributor != null && contributor.id.isNotEmpty) {
      contributors[contributor.id] = contributor;
    }
  }
  final result = contributors.values.toList()
    ..sort((a, b) => a.username.compareTo(b.username));
  return result;
}

List<String> movieListPosterUrls(List<MovieListMovie> movies) {
  return movies
      .map((entry) => entry.movie?.posterPath ?? entry.show?.posterPath)
      .whereType<String>()
      .take(4)
      .map((path) => 'https://image.tmdb.org/t/p/w342$path')
      .toList(growable: false);
}

int entryMovieId(MovieListMovie entry) {
  return entry.movieId != 0 ? entry.movieId : entry.movie?.id ?? 0;
}

int entryShowId(MovieListMovie entry) {
  return entry.showId != 0 ? entry.showId : entry.show?.id ?? 0;
}

int entryReleaseYear(MovieListMovie entry) =>
    int.tryParse(
        extractYear(entry.movie?.releaseDate ?? entry.show?.firstAirDate) ??
            '') ??
    0;

String entryTitle(MovieListMovie entry) {
  return entry.movie?.title ?? entry.show?.name ?? 'Unknown title';
}

double? entryRating(MovieListMovie entry) {
  return entry.movie?.voteAverage ?? entry.show?.voteAverage;
}

String addedByUsername(MovieListMovie entry, String? currentUserId) {
  final byYou = entry.addedBy?.id.isNotEmpty == true &&
      entry.addedBy!.id == currentUserId;
  return byYou ? '@you' : '@${entry.addedBy?.username ?? 'someone'}';
}

bool isRecentAddition(String? value) {
  final addedAt = value == null ? null : DateTime.tryParse(value);
  if (addedAt == null) return false;
  return DateTime.now().difference(addedAt.toLocal()) <=
      const Duration(hours: 48);
}

String mediaCountLabel(int movieCount, int showCount) {
  final parts = <String>[];
  if (movieCount > 0) {
    parts.add('$movieCount ${movieCount == 1 ? 'movie' : 'movies'}');
  }
  if (showCount > 0) {
    parts.add('$showCount ${showCount == 1 ? 'show' : 'shows'}');
  }
  return parts.isEmpty ? 'Empty collection' : parts.join(' & ');
}

String? extractYear(String? releaseDate) {
  if (releaseDate == null || releaseDate.isEmpty) return null;
  final parsed = DateTime.tryParse(releaseDate);
  if (parsed != null) return parsed.year.toString();
  return releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
}

String sortLabel(MovieListSort sort) {
  return switch (sort) {
    MovieListSort.recentlyAdded => 'Recently added',
    MovieListSort.title => 'Title',
    MovieListSort.releaseYear => 'Release year',
    MovieListSort.rating => 'Rating',
    MovieListSort.addedBy => 'Added by',
  };
}

(String, String?) listIdentity(String name) {
  const marker = ' with @';
  final index = name.indexOf(marker);
  if (index <= 0) return (name, null);
  return (name.substring(0, index), name.substring(index));
}

String visibilityLabel(String? visibility) {
  return switch (visibility?.toUpperCase()) {
    'PUBLIC' => 'Public',
    'FRIENDS' => 'Friends',
    _ => 'Private',
  };
}

String addedDateLabel(String? value) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return 'Added';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'Added today';
  if (days == 1) return 'Added yesterday';
  if (days < 7) return 'Added $days days ago';
  if (days < 14) return 'Added last week';
  if (days < 30) {
    final weeks = days ~/ 7;
    return 'Added $weeks weeks ago';
  }
  if (days < 60) return 'Added last month';
  final months = days ~/ 30;
  return 'Added $months months ago';
}
