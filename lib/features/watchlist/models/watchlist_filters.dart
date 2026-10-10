import '../domain/release_status.dart';
import '../domain/tonight_filters.dart';

/// Editable filter choices; apply changes through WatchlistController.updateFilters.
class WatchlistFilters {
  WatchlistFilters();

  WatchlistFilters.copy(WatchlistFilters source) {
    media = source.media;
    sort = source.sort;
    tab = source.tab;
    mood = source.mood;
    avoid = Set.of(source.avoid);
    request = source.request;
    findingToday = source.findingToday;
    servicesOnly = source.servicesOnly;
    includeRentals = source.includeRentals;
    providerIds =
        source.providerIds == null ? null : Set.of(source.providerIds!);
    genre = source.genre;
    minRating = source.minRating;
    year = source.year;
    maxRuntime = source.maxRuntime;
    release = source.release;
    friendsOnly = source.friendsOnly;
  }

  int media = 0;
  String sort = 'recent';
  int tab = 0;
  WatchlistMood mood = WatchlistMood.any;
  Set<String> avoid = {};
  String request = '';
  bool findingToday = false;
  bool servicesOnly = false;
  bool includeRentals = false;
  Set<int>? providerIds;
  String? genre;
  double? minRating;
  int? year;
  int? maxRuntime;
  ReleaseStatus? release;
  bool friendsOnly = false;
}
