import 'package:flixie_app/core/auth/referral_attribution_store.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/genre.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/settings/data/reference_data_service.dart';
import 'package:flixie_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';

class SetupTitle {
  const SetupTitle(this.id, this.name, this.poster, {this.isShow = false});
  final int id;
  final String name;
  final String? poster;
  final bool isShow;
  String get key => '${isShow ? 'show' : 'movie'}:$id';
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'poster': poster, 'isShow': isShow};
  factory SetupTitle.fromJson(Map<String, dynamic> json) => SetupTitle(
      json['id'] as int, json['name'] as String, json['poster'] as String?,
      isShow: json['isShow'] == true);
}

/// Setup taste is intentionally independent of favourites, ratings and watches.
class SetupTasteStore {
  static String key(String userId) => 'setup_taste_v1:$userId';
  static Future<void> save(String userId, List<SetupTitle> titles) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
        key(userId), jsonEncode(titles.map((t) => t.toJson()).toList()))) {
      throw StateError('Could not save taste');
    }
  }

  static Future<List<SetupTitle>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key(userId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => SetupTitle.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class SetupService {
  const SetupService();
  static Future<void> rememberInviter(String id, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setup_inviter_v1:$id', username);
  }

  Future<String?> referrer(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('setup_inviter_v1:$userId');
    if (stored != null) return stored;
    final code = await SharedPreferencesReferralAttributionStore().read();
    return code == null ? null : UserService.lookupReferralUsername(code);
  }

  Future<String?> friendId(String username) async {
    final users = await UserService.searchUsers(username);
    return users
        .where((u) => u.username.toLowerCase() == username.toLowerCase())
        .firstOrNull
        ?.id;
  }

  Future<List<Country>> countries() => ReferenceDataService.getCountries();
  Future<List<WatchProvider>> providers() =>
      ReferenceDataService.getWatchProviders();
  Future<List<Genre>> genres() => ReferenceDataService.getGenres();
  Future<List<SetupTitle>> loadTaste(String id) => SetupTasteStore.load(id);
  Future<List<WatchProvider>> savedProviders(String id) =>
      UserService.getUserWatchProviders(id);
  Future<void> saveWatching(
      String id, Country country, Set<int> providers) async {
    await UserService.updateUserField(id, 'countryId', country.id);
    await SettingsController.instance
        .updateUserWatchProviders(id, providers.toList());
  }

  Future<void> saveTaste(
      String id, List<SetupTitle> titles, Set<int> genres) async {
    // Singleton bulk requests import missing titles, preserve selection order,
    // and safely skip already-saved favourites when retrying a partial failure.
    for (final title in titles) {
      if (title.isShow) {
        await UserService.addShowsToFavorites(id, [title.id]);
      } else {
        await UserService.addMoviesToFavorites(id, [title.id]);
      }
    }
    await SetupTasteStore.save(id, titles);
    if (genres.isNotEmpty) {
      await UserService.addFavoriteGenres(id, genres.toList());
    }
  }

  Future<List<SetupTitle>> search(String query, bool shows) async {
    final results =
        await SearchService.search(query, type: shows ? 'tv' : 'movie');
    return results.results
        .where((r) => shows ? r.show != null : r.movie != null)
        .map((r) => shows
            ? SetupTitle(r.show!.id, r.show!.name, r.show!.posterPath,
                isShow: true)
            : SetupTitle(r.movie!.id, r.movie!.name, r.movie!.poster))
        .toList();
  }

  Future<List<SetupTitle>> popular(bool shows) async {
    Object? failure;
    Future<List<T>> available<T>(Future<List<T>> request) async {
      try {
        return await request;
      } catch (error) {
        failure = error;
        return [];
      }
    }

    if (shows) {
      final sources = await Future.wait([
        available(TrendingService.getTrendingShows()),
        available(ShowService.getTopRatedShows()),
      ]);
      if (sources.every((source) => source.isEmpty) && failure != null) {
        throw failure!;
      }
      return _blendSetupRanked(sources[0], sources[1], (show) => show.id)
          .map((show) =>
              SetupTitle(show.id, show.name, show.posterPath, isShow: true))
          .toList();
    }
    final sources = await Future.wait([
      available(TrendingService.getTrendingMovies()),
      available(MovieService().getTopRatedMovies()),
    ]);
    if (sources.every((source) => source.isEmpty) && failure != null) {
      throw failure!;
    }
    return blendSetupMovies(sources[0], sources[1])
        .map((movie) => SetupTitle(movie.id, movie.name, movie.poster))
        .toList();
  }

  Future<List<SetupTitle>> recommendations(List<SetupTitle> seeds) async {
    if (seeds.isEmpty) return (await popular(false)).take(6).toList();
    final rows = await Future.wait(seeds.take(5).map((seed) async {
      if (seed.isShow) {
        final show = await ShowService.getShowById(seed.id);
        return show.similarShows
            .take(6)
            .map((s) => SetupTitle(s.id, s.name, s.posterPath, isShow: true))
            .toList();
      }
      return (await MovieService().getMovieRecommendations(seed.id))
          .take(6)
          .map((m) => SetupTitle(m.id, m.title, m.posterPath))
          .toList();
    }));
    final seen = seeds.map((s) => s.key).toSet();
    final result = <SetupTitle>[];
    for (var i = 0; i < 6; i++) {
      for (final row in rows) {
        if (i < row.length && seen.add(row[i].key)) result.add(row[i]);
      }
    }
    return result.take(6).toList();
  }

  Future<List<WatchProvider>> availability(SetupTitle title, String region) =>
      title.isShow
          ? ShowService.getShowWatchProviders(title.id, region)
          : MovieService().getMovieWatchProviders(title.id, region);
  Future<void> addToWatchlist(String userId, SetupTitle title) => title.isShow
      ? ShowService.addToWatchlist(userId, title.id)
      : MovieService().addToWatchlist(userId, title.id);
  static Future<List<MovieShort>> movieSeeds(String userId) async {
    final seeds =
        (await SetupTasteStore.load(userId)).where((s) => !s.isShow).toList();
    if (seeds.isEmpty) return [];
    return (await const SetupService().recommendations(seeds))
        .map((t) => MovieShort(id: t.id, name: t.name, poster: t.poster))
        .toList();
  }
}

/// Put familiar services first, retaining the catalogue priority for the rest.
/// Region flags in the catalogue are incomplete; title availability is regional.
List<WatchProvider> setupProviders(List<WatchProvider> providers,
    {String query = ''}) {
  int priority(WatchProvider provider) => switch (provider.matchKey) {
        'appletv' || 'appletvplus' => 0,
        'netflix' => 1,
        'disneyplus' || 'disney' => 2,
        'hbo' || 'hbomax' || 'max' => 3,
        'amazonprimevideo' || 'primevideo' => 4,
        'now' || 'nowtv' || 'nowtvcinema' => 5,
        _ => 6,
      };
  final search = canonicalWatchProviderName(query);
  return providers
      .where((p) => p.isVisible && p.matchKey.contains(search))
      .toList()
    ..sort((a, b) {
      final popular = priority(a).compareTo(priority(b));
      if (popular != 0) return popular;
      final catalogue = a.displayPriority.compareTo(b.displayPriority);
      return catalogue != 0
          ? catalogue
          : a.providerName.compareTo(b.providerName);
    });
}

/// Preserve upstream popularity and all-time rating ranks while giving both
/// sources room near the start. These APIs do not supply popularity scores.
List<MovieShort> blendSetupMovies(
        List<MovieShort> popular, List<MovieShort> topRated) =>
    _blendSetupRanked(popular, topRated, (movie) => movie.id);

List<T> _blendSetupRanked<T>(
    List<T> popular, List<T> topRated, int Function(T) id) {
  final result = <T>[];
  final seen = <int>{};
  final length =
      popular.length > topRated.length ? popular.length : topRated.length;
  for (var index = 0; index < length; index++) {
    for (final source in [popular, topRated]) {
      if (index < source.length && seen.add(id(source[index]))) {
        result.add(source[index]);
      }
    }
  }
  return result;
}
