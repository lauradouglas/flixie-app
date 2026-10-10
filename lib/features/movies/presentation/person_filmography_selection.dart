import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/models/user.dart';

enum PersonRoleFilter { all, actor, director, writer, producer }

enum PersonMediaFilter { all, movies, tv }

extension PersonMediaFilterView on PersonMediaFilter {
  String get label => switch (this) {
        PersonMediaFilter.all => 'All',
        PersonMediaFilter.movies => 'Movies',
        PersonMediaFilter.tv => 'TV',
      };
}

enum PersonCreditSort { popular, newest, oldest, rating }

enum PersonPersonalFilter { all, watched, watchlist, favourites }

extension PersonPersonalFilterView on PersonPersonalFilter {
  String get label => switch (this) {
        PersonPersonalFilter.all => 'All titles',
        PersonPersonalFilter.watched => 'Watched',
        PersonPersonalFilter.watchlist => 'Watchlist',
        PersonPersonalFilter.favourites => 'Favourites',
      };
}

extension PersonRoleFilterView on PersonRoleFilter {
  String get label => switch (this) {
        PersonRoleFilter.all => 'All',
        PersonRoleFilter.actor => 'Actor',
        PersonRoleFilter.director => 'Director',
        PersonRoleFilter.writer => 'Writer',
        PersonRoleFilter.producer => 'Producer',
      };
}

extension PersonCreditSortView on PersonCreditSort {
  String get label => switch (this) {
        PersonCreditSort.popular => 'Popular',
        PersonCreditSort.newest => 'Newest',
        PersonCreditSort.oldest => 'Oldest',
        PersonCreditSort.rating => 'Rating',
      };
}

class PersonFilmCredit {
  const PersonFilmCredit({
    required this.id,
    required this.title,
    required this.type,
    required this.posterPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    required this.roles,
    required this.isCast,
    required this.jobs,
  });

  final int id;
  final String title;
  final String type;
  final String? posterPath;
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;
  final double popularity;
  final List<String> roles;
  final bool isCast;
  final List<String> jobs;

  bool get isMovie => type == 'movie';

  String? get year => releaseDate != null && releaseDate!.length >= 4
      ? releaseDate!.substring(0, 4)
      : null;

  String get roleLabel {
    final allRoles = [
      ...roles.where((role) => role.trim().isNotEmpty),
      ...jobs.where((job) => job.trim().isNotEmpty),
    ];
    return allRoles.isEmpty ? 'Credit' : allRoles.toSet().take(2).join(', ');
  }

  bool get isDirector =>
      jobs.any((job) => job.toLowerCase().contains('director'));

  bool get isWriter {
    return jobs.any((job) {
      final lower = job.toLowerCase();
      return lower.contains('writer') ||
          lower.contains('screenplay') ||
          lower.contains('story');
    });
  }

  bool get isProducer =>
      jobs.any((job) => job.toLowerCase().contains('producer'));
}

class PersonFilmographyFilters {
  const PersonFilmographyFilters(
      {this.role = PersonRoleFilter.all,
      this.media = PersonMediaFilter.all,
      this.personal = PersonPersonalFilter.all,
      this.sort = PersonCreditSort.newest,
      this.query = '',
      this.year});
  final PersonRoleFilter role;
  final PersonMediaFilter media;
  final PersonPersonalFilter personal;
  final PersonCreditSort sort;
  final String query;
  final String? year;
  PersonFilmographyFilters copyWith(
          {PersonRoleFilter? role,
          PersonMediaFilter? media,
          PersonPersonalFilter? personal,
          PersonCreditSort? sort,
          String? query,
          String? year,
          bool clearYear = false}) =>
      PersonFilmographyFilters(
          role: role ?? this.role,
          media: media ?? this.media,
          personal: personal ?? this.personal,
          sort: sort ?? this.sort,
          query: query ?? this.query,
          year: clearYear ? null : year ?? this.year);
}

class PersonLibraryStatus {
  PersonLibraryStatus(
      {Iterable<int> watched = const [],
      Iterable<int> watchlist = const [],
      Iterable<int> favourites = const []})
      : watched = Set.unmodifiable(watched),
        watchlist = Set.unmodifiable(watchlist),
        favourites = Set.unmodifiable(favourites);
  factory PersonLibraryStatus.fromUser(User? user) => PersonLibraryStatus(
      watched: user?.watchedMovies?.map((m) => m.movieId) ?? const [],
      watchlist: user?.movieWatchlist?.map((m) => m.movieId) ?? const [],
      favourites: user?.favoriteMovies?.map((m) => m.movieId) ?? const []);
  final Set<int> watched, watchlist, favourites;
}

List<PersonFilmCredit> mergePersonCredits(PersonCredits credits) {
  final byId = <String, PersonFilmCredit>{};

  for (final item in credits.allCredits) {
    final key = '${item.type}:${item.id}';
    byId[key] = PersonFilmCredit(
      id: item.id,
      title: item.title,
      type: item.type,
      posterPath: item.posterPath,
      releaseDate: item.releaseDate,
      voteAverage: item.voteAverage,
      voteCount: item.voteCount,
      popularity: item.popularity,
      roles: item.characters,
      isCast: true,
      jobs: const [],
    );
  }

  for (final item in credits.crewCredits) {
    final key = '${item.type}:${item.id}';
    final existing = byId[key];
    if (existing == null) {
      byId[key] = PersonFilmCredit(
        id: item.id,
        title: item.title,
        type: item.type,
        posterPath: item.posterPath,
        releaseDate: item.releaseDate,
        voteAverage: item.voteAverage,
        voteCount: item.voteCount,
        popularity: item.popularity,
        roles: const [],
        isCast: false,
        jobs: [item.job],
      );
    } else {
      byId[key] = PersonFilmCredit(
        id: existing.id,
        title: existing.title,
        type: existing.type,
        posterPath: existing.posterPath,
        releaseDate: existing.releaseDate,
        voteAverage: existing.voteAverage,
        voteCount: existing.voteCount,
        popularity: existing.popularity,
        roles: existing.roles,
        isCast: existing.isCast,
        jobs: {...existing.jobs, item.job}.toList(),
      );
    }
  }

  return byId.values.toList();
}

List<PersonFilmCredit> selectPersonCredits(List<PersonFilmCredit> credits,
    {required PersonFilmographyFilters filters,
    required PersonLibraryStatus library,
    DateTime? now}) {
  final filtered = credits.where((credit) {
    final matchesRole = switch (filters.role) {
      PersonRoleFilter.all => true,
      PersonRoleFilter.actor => credit.isCast,
      PersonRoleFilter.director => credit.isDirector,
      PersonRoleFilter.writer => credit.isWriter,
      PersonRoleFilter.producer => credit.isProducer,
    };
    final matchesMedia = switch (filters.media) {
      PersonMediaFilter.all => true,
      PersonMediaFilter.movies => credit.isMovie,
      PersonMediaFilter.tv => !credit.isMovie,
    };
    final query = filters.query.trim().toLowerCase();
    final matchesQuery = query.isEmpty ||
        credit.title.toLowerCase().contains(query) ||
        [...credit.roles, ...credit.jobs]
            .any((role) => role.toLowerCase().contains(query));
    final matchesYear = filters.year == null || credit.year == filters.year;
    final matchesPersonal = switch (filters.personal) {
      PersonPersonalFilter.all => true,
      PersonPersonalFilter.watched =>
        credit.isMovie && library.watched.contains(credit.id),
      PersonPersonalFilter.watchlist =>
        credit.isMovie && library.watchlist.contains(credit.id),
      PersonPersonalFilter.favourites =>
        credit.isMovie && library.favourites.contains(credit.id),
    };
    return matchesRole &&
        matchesMedia &&
        matchesQuery &&
        matchesYear &&
        matchesPersonal;
  }).toList();

  filtered.sort((a, b) {
    return switch (filters.sort) {
      PersonCreditSort.popular => b.popularity.compareTo(a.popularity),
      PersonCreditSort.newest =>
        _compareNewestReleasedFirst(a, b, now ?? DateTime.now()),
      PersonCreditSort.oldest =>
        (a.releaseDate ?? '9999').compareTo(b.releaseDate ?? '9999'),
      PersonCreditSort.rating => b.voteAverage.compareTo(a.voteAverage),
    };
  });
  return filtered;
}

int _compareNewestReleasedFirst(
  PersonFilmCredit a,
  PersonFilmCredit b,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final aDate = DateTime.tryParse(a.releaseDate ?? '');
  final bDate = DateTime.tryParse(b.releaseDate ?? '');
  final aIsFuture = aDate != null && aDate.isAfter(today);
  final bIsFuture = bDate != null && bDate.isAfter(today);

  // Keep unreleased credits visible, but below titles that are already out.
  if (aIsFuture != bIsFuture) return aIsFuture ? 1 : -1;
  return (b.releaseDate ?? '').compareTo(a.releaseDate ?? '');
}
