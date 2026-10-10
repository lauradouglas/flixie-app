import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

import '../domain/release_status.dart';
import '../domain/tonight_filters.dart';
import '../models/watchlist_filters.dart';
import '../models/watchlist_show_entry.dart';

/// Pure projection of the library and current filter choices. No I/O or listeners.
class WatchlistSelection {
  WatchlistSelection({
    required this.filters,
    required this.searchQuery,
    required this.movies,
    required this.shows,
    required this.user,
    required this.movieFriends,
    required this.showFriends,
    required this.movieProviders,
    required this.showProviders,
    required this.experienceFits,
    required this.usesExperience,
    required this.fitsExperience,
    required this.matchesServices,
    required this.canWatchMovie,
    required this.isUserProvider,
  }) {
    _filter();
  }

  final WatchlistFilters filters;
  final String searchQuery;
  final List<WatchlistMovie> movies;
  final List<WatchlistShowEntry> shows;
  final User? user;
  final Map<int, List<FriendRecommendationItem>> movieFriends, showFriends;
  final Map<int, List<WatchProvider>> movieProviders, showProviders;
  final Map<String, ExperienceFit> experienceFits;
  final bool usesExperience;
  final bool Function(String) fitsExperience;
  final bool Function(List<WatchProvider>) matchesServices;
  final bool Function(int) canWatchMovie;
  final bool Function(WatchProvider) isUserProvider;
  List<WatchlistMovie> _filteredWatchlist = [];
  List<WatchlistShowEntry> _filteredShowWatchlist = [];

  bool get comingSoonOnly =>
      filters.release == ReleaseStatus.comingSoon || filters.tab == 2;
  String _key(Object item) => item is WatchlistMovie
      ? 'movie:${item.movieId}'
      : 'show:${(item as WatchlistShowEntry).showId}';

  void _filter() {
    final query = searchQuery.toLowerCase();

    _filteredWatchlist = movies.where((item) {
      final m = item.movie;
      if (m == null) return false;
      if (filters.release != null &&
          releaseStatus(m.releaseDate) != filters.release) {
        return false;
      }
      if (!fitsExperience('movie:${item.movieId}') ||
          !matchesServices(movieProviders[item.movieId] ?? [])) {
        return false;
      }
      if (filters.friendsOnly &&
          !(movieFriends[item.movieId]?.any((f) => f.watched) ?? false)) {
        return false;
      }
      // Text search
      if (!m.title.toLowerCase().contains(query)) return false;
      // Genre filter
      if (!_matchesGenre(m.genres)) {
        return false;
      }
      // Min rating filter
      if (filters.minRating != null &&
          (m.voteAverage ?? 0) < filters.minRating!) {
        return false;
      }
      // Year filter
      if (filters.year != null) {
        final year = int.tryParse(m.releaseDate?.split('-').first ?? '');
        if (year != filters.year) return false;
      }
      // Max runtime filter
      if (!fitsWatchTime(m.runtime, filters.maxRuntime)) {
        return false;
      }
      return true;
    }).toList();
    _filteredShowWatchlist = shows.where((item) {
      if (!item.title.toLowerCase().contains(query)) return false;
      if (filters.release != null &&
          releaseStatus(item.firstAirDate) != filters.release) {
        return false;
      }
      if (!fitsExperience('show:${item.showId}') ||
          !matchesServices(showProviders[item.showId] ?? [])) {
        return false;
      }
      if (filters.friendsOnly &&
          !(showFriends[item.showId]?.any((f) => f.watched) ?? false)) {
        return false;
      }
      if (!_matchesGenre(item.genres)) {
        return false;
      }
      if (filters.year != null &&
          int.tryParse(item.firstAirDate?.split('-').first ?? '') !=
              filters.year) {
        return false;
      }
      if (filters.minRating != null &&
          (item.voteAverage == null ||
              item.voteAverage! < filters.minRating!)) {
        return false;
      }
      if (!fitsWatchTime(item.runtime, filters.maxRuntime)) {
        return false;
      }
      return true;
    }).toList()
      ..sort(_compareWatchlistItems);

    // Apply sorting
    switch (filters.sort) {
      case 'runtimeAsc':
        _filteredWatchlist.sort(_compareWatchlistItems);
        break;
      case 'recent':
        _filteredWatchlist.sort((a, b) {
          final dateA = DateTime.tryParse(a.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        break;
      case 'titleAsc':
        _filteredWatchlist.sort(
            (a, b) => (a.movie?.title ?? '').compareTo(b.movie?.title ?? ''));
        break;
      case 'titleDesc':
        _filteredWatchlist.sort(
            (a, b) => (b.movie?.title ?? '').compareTo(a.movie?.title ?? ''));
        break;
      case 'ratingDesc':
        _filteredWatchlist.sort((a, b) =>
            (b.movie?.voteAverage ?? 0).compareTo(a.movie?.voteAverage ?? 0));
        break;
      case 'yearDesc':
        _filteredWatchlist.sort((a, b) {
          final yA =
              int.tryParse(a.movie?.releaseDate?.split('-').first ?? '') ?? 0;
          final yB =
              int.tryParse(b.movie?.releaseDate?.split('-').first ?? '') ?? 0;
          return yB.compareTo(yA);
        });
        break;
      case 'yearAsc':
        _filteredWatchlist.sort((a, b) {
          final yA =
              int.tryParse(a.movie?.releaseDate?.split('-').first ?? '') ?? 0;
          final yB =
              int.tryParse(b.movie?.releaseDate?.split('-').first ?? '') ?? 0;
          return yA.compareTo(yB);
        });
        break;
    }
  }

  bool _matchesGenre(List<String> genres) =>
      filters.genre == null ||
      (filters.genre == 'Rom com'
          ? genres.contains('Comedy') && genres.contains('Romance')
          : genres.contains(filters.genre));

  List<String> allGenres() {
    final genres = <String>{'Rom com'};
    for (final item in movies) {
      genres.addAll(item.movie?.genres ?? []);
    }
    for (final show in shows) {
      genres.addAll(show.genres);
    }
    return genres.toList()..sort();
  }

  List<int> allYears() {
    final years = <int>{};
    for (final item in movies) {
      final y = int.tryParse(item.movie?.releaseDate?.split('-').first ?? '');
      if (y != null) years.add(y);
    }
    for (final show in shows) {
      final year = int.tryParse(show.firstAirDate?.split('-').first ?? '');
      if (year != null) years.add(year);
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  List<WatchlistMovie> _visibleWatchlist() {
    if (filters.media == 2) return const [];
    if (filters.tab == 3) {
      // Watched: watchlist items also in watchedMovies
      final watchedIds =
          user?.watchedMovies?.map((w) => w.movieId).toSet() ?? <int>{};
      return _filteredWatchlist
          .where((item) => watchedIds.contains(item.movieId))
          .toList();
    }
    if (filters.tab == 2) {
      final upcoming = _filteredWatchlist.where((item) {
        return releaseStatus(item.movie?.releaseDate) ==
            ReleaseStatus.comingSoon;
      }).toList();
      upcoming.sort((a, b) {
        final dateA = DateTime.tryParse(a.movie?.releaseDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b.movie?.releaseDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });
      return upcoming;
    }
    if (filters.tab == 1) {
      return _filteredWatchlist
          .where((item) => canWatchMovie(item.movieId))
          .toList();
    }
    return _filteredWatchlist;
  }

  List<WatchlistShowEntry> _visibleShowWatchlist() {
    if (filters.media == 1) return const [];
    if (filters.tab == 3) {
      final watched = user?.watchedShows ?? const [];
      final ids = watched
          .whereType<Map>()
          .where((w) => w['removed'] != true)
          .map((w) => watchlistInt(w['showId']))
          .toSet();
      return _filteredShowWatchlist
          .where((item) => item.watched || ids.contains(item.showId))
          .toList();
    }
    if (filters.tab == 1) {
      return _filteredShowWatchlist.where((item) {
        final providers = showProviders[item.showId] ?? const [];
        return providers.any(
          (provider) => provider.isIncludedOffer && isUserProvider(provider),
        );
      }).toList();
    }
    if (filters.tab == 2) {
      final upcoming = _filteredShowWatchlist.where((item) {
        return releaseStatus(item.firstAirDate) == ReleaseStatus.comingSoon;
      }).toList();
      upcoming.sort((a, b) {
        final dateA = DateTime.tryParse(a.firstAirDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b.firstAirDate ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });
      return upcoming;
    }
    return _filteredShowWatchlist;
  }

  int _compareWatchlistItems(Object first, Object second) {
    if (filters.sort == 'runtimeAsc') {
      int value(Object item) =>
          (item is WatchlistMovie
              ? item.movie?.runtime
              : (item as WatchlistShowEntry).runtime) ??
          999999;
      final comparison = value(first).compareTo(value(second));
      if (comparison != 0) return comparison;
    }
    final firstTitle = first is WatchlistMovie
        ? first.movie?.title ?? ''
        : (first as WatchlistShowEntry).title;
    final secondTitle = second is WatchlistMovie
        ? second.movie?.title ?? ''
        : (second as WatchlistShowEntry).title;
    if (filters.sort == 'titleAsc') return firstTitle.compareTo(secondTitle);
    if (filters.sort == 'titleDesc') return secondTitle.compareTo(firstTitle);

    if (filters.sort == 'ratingDesc' ||
        filters.sort == 'yearAsc' ||
        filters.sort == 'yearDesc') {
      double? value(Object item) {
        if (filters.sort == 'ratingDesc') {
          return item is WatchlistMovie
              ? item.movie?.voteAverage
              : (item as WatchlistShowEntry).voteAverage;
        }
        final date = item is WatchlistMovie
            ? item.movie?.releaseDate
            : (item as WatchlistShowEntry).firstAirDate;
        return double.tryParse(date?.split('-').first ?? '');
      }

      final a = value(first), b = value(second);
      if (a == null && b != null) return 1;
      if (b == null && a != null) return -1;
      if (a != null && b != null && a != b) {
        return filters.sort == 'yearAsc' ? a.compareTo(b) : b.compareTo(a);
      }
    }
    final firstAddedAt = DateTime.tryParse(first is WatchlistMovie
            ? first.createdAt ?? ''
            : (first as WatchlistShowEntry).createdAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final secondAddedAt = DateTime.tryParse(second is WatchlistMovie
            ? second.createdAt ?? ''
            : (second as WatchlistShowEntry).createdAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return secondAddedAt.compareTo(firstAddedAt);
  }

  List<Object> get visibleItems {
    final movieItems = _visibleWatchlist();
    final showItems = _visibleShowWatchlist();
    final items = <Object>[...movieItems, ...showItems];
    if (filters.media == 0) items.sort(_compareWatchlistItems);
    if (usesExperience) {
      items.sort((a, b) =>
          experienceFits[_key(a)]!.compareTo(experienceFits[_key(b)]!));
    }
    if (comingSoonOnly) {
      DateTime releaseDate(Object item) =>
          DateTime.parse((item is WatchlistMovie
                  ? item.movie!.releaseDate!
                  : (item as WatchlistShowEntry).firstAirDate!)
              .substring(0, 10));
      items.sort((a, b) {
        final byDate = releaseDate(a).compareTo(releaseDate(b));
        return byDate != 0 ? byDate : _compareWatchlistItems(a, b);
      });
    }
    return items;
  }
}
