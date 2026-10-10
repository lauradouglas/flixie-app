import 'package:flutter/foundation.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_detail_sections_controller.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/movie_images.dart';
import 'package:flixie_app/models/movie_credits.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/models/movie_friend_list_entry.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/similar_movie.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/models/friend_summary.dart';

enum ListUpdateType { watchlist, watched, favorite }

/// Movie Detail data, progressive loading and persisted-action state.
class MovieDetailController extends ChangeNotifier {
  MovieDetailController(
      {required this.auth,
      required this.service,
      this.actions = WatchlistActionsController.instance}) {
    _sections = MovieDetailSectionsController(viewerId: () => auth.dbUser?.id)
      ..addListener(_publish);
  }
  final AuthProvider auth;
  final MovieService service;
  final WatchlistActionsController actions;
  late final MovieDetailSectionsController _sections;
  String? _rawId;
  int? get movieId => int.tryParse(_rawId ?? '');
  int _loadGeneration = 0;
  int get generation => _loadGeneration;
  bool _disposed = false;
  bool get isDisposed => _disposed;
  Map<String, String> get sectionStates => _sections.states;
  Map<String, Future<void> Function()> get sectionRetries => _sections.retries;
  Set<String> get loadedSections => _sections.loaded;

  Movie? movie;
  List<Review> reviews = [];
  List<SimilarMovie> similar = [];
  List<MovieCastMember> cast = [];
  MovieImages movieImages = const MovieImages();
  bool get movieImagesLoading => sectionStates['images'] == 'loading';
  List<WatchProvider> watchProviders = [];
  Set<int> userProviderIds = {};
  Set<String> userProviderMatchKeys = {};
  CrewMember? director;
  List<String> producers = [];
  List<String> writers = [];
  bool isLoading = true;
  String? error;
  bool inWatchlist = false;
  bool isWatched = false;
  bool isFavorite = false;
  int? userRating;
  ListUpdateType? currentlyUpdating;
  List<MovieFriendActivity> friendsActivity = [];
  FriendSummaryResponse? friendSummary;
  bool get friendSummaryLoading => sectionStates['friend summary'] == 'loading';
  Object? friendSummaryError;
  List<MovieList> myListsContainingMovie = [];
  List<MovieFriendListEntry> friendsListsContainingMovie = [];
  bool get listsContainingMovieLoading => sectionStates['lists'] == 'loading';
  List<MovieWatchEntry> movieWatchHistory = [];
  bool get watchHistoryLoading => sectionStates['history'] == 'loading';
  bool watchHistoryLoaded = false;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  void change(VoidCallback update) {
    if (_disposed) return;
    update();
    _publish();
  }

  Future<void> _optional<T>(
          String key, Future<T> Function() fetch, void Function(T) apply) =>
      _sections.load(key, fetch, apply);
  Future<void> refresh(String rawId) async {
    final id = int.tryParse(rawId);
    if (id != null) service.evictMovie(id);
    await load(rawId);
  }

  Future<void> load(String rawId) async {
    if (_disposed) return;
    if (_rawId != rawId) {
      movie = null;
      isLoading = true;
      currentlyUpdating = null;
    }
    _rawId = rawId;
    final generation = ++_loadGeneration;
    final id = movieId;
    if (id == null || id <= 0) {
      change(() {
        error = 'Invalid movie ID.';
        isLoading = false;
      });
      return;
    }
    final userId = auth.dbUser?.id;
    change(() {
      error = null;
      _sections.begin(clearLoaded: movie == null);
      if (movie == null) {
        similar = [];
        cast = [];
        director = null;
        writers = [];
        producers = [];
        watchProviders = [];
        movieImages = const MovieImages();
        userRating = null;
        reviews = [];
        friendsActivity = [];
        friendSummary = null;
        movieWatchHistory = [];
        watchHistoryLoaded = false;
        myListsContainingMovie = [];
        friendsListsContainingMovie = [];
        userProviderIds = {};
        userProviderMatchKeys = {};
      }
    });
    final core = service.getMovieById(id);
    final optional = <Future<void>>[
      _optional('similar', () => service.getMovieRecommendations(id),
          (value) => similar = value),
      _optional('credits', () => service.getMovieCredits(id), (credits) {
        cast = credits.castMembers;
        director = credits.crewMembers
            .where((crew) => crew.job == 'Director')
            .firstOrNull;
        producers = <String>{
          ...credits.crewMembers
              .where((crew) => crew.job == 'Executive Producer')
              .map((crew) => crew.name),
          ...credits.crewMembers
              .where((crew) => crew.job == 'Producer')
              .map((crew) => crew.name),
        }.toList();
        writers = credits.crewMembers
            .where((crew) =>
                crew.job == 'Screenplay' || crew.job == 'Head of Story')
            .map((crew) => crew.name)
            .toSet()
            .toList();
      }),
      _optional(
          'providers',
          () => service.getMovieWatchProviders(
              id, auth.dbUser?.watchProviderRegion ?? 'GB'),
          (value) => watchProviders = value),
      if (userId != null) ...[
        _optional('your providers', () => actions.getUserWatchProviders(userId),
            (value) {
          userProviderIds = value.map((provider) => provider.id).toSet();
          userProviderMatchKeys =
              value.map((provider) => provider.matchKey).toSet();
        }),
        _optional('rating', () => service.getUserMovieRating(id, userId),
            (value) {
          userRating = value.rating;
        }),
        _optional('activity', () => service.getFriendsMovieActivity(id, userId),
            (value) => friendsActivity = value),
        loadWatchHistory(userId, id),
        loadListsContainingMovie(userId, id),
        loadFriendSummary(id),
      ],
    ];
    try {
      final movie = await core;
      if (_disposed ||
          generation != _loadGeneration ||
          userId != auth.dbUser?.id) {
        return;
      }
      change(() {
        this.movie = movie;
        final user = auth.dbUser;
        inWatchlist = user?.isMovieInWatchlist(id) ?? false;
        isWatched = watchHistoryLoaded
            ? movieWatchHistory.isNotEmpty
            : (user?.isMovieWatched(id) ?? false);
        isFavorite = user?.isMovieFavorite(id) ?? false;
        isLoading = false;
      });
    } catch (error) {
      if (_disposed ||
          generation != _loadGeneration ||
          userId != auth.dbUser?.id) {
        return;
      }
      change(() {
        this.error = error.toString();
        isLoading = false;
      });
    }
    // Hidden-tab data warms after core content, without delaying friends or
    // adding any new loading UI. A replaced route must not start more work.
    if (!_disposed &&
        generation == _loadGeneration &&
        userId == auth.dbUser?.id &&
        movie != null) {
      optional.addAll([
        _optional('reviews', () => service.getMovieReviews(id, userId: userId),
            (value) => reviews = value),
        _loadMovieImages(id),
      ]);
    }
    // Pull-to-refresh completes only once its optional work has settled.
    // Rendering above does not wait for it.
    await Future.wait(optional);
  }

  Future<void> _loadMovieImages(int id) => _optional('images',
      () => service.getMovieImages(id), (value) => movieImages = value);

  Future<void> loadWatchHistory(String userId, int id) =>
      _optional('history', () => actions.getMovieWatchHistory(userId, id),
          (value) {
        movieWatchHistory = value;
        watchHistoryLoaded = true;
        isWatched = value.isNotEmpty;
      });

  Future<void> loadFriendSummary(int id) => _optional('friend summary',
      () => service.getFriendSummary(id), (value) => friendSummary = value);

  Future<void> loadListsContainingMovie(String userId, int id) =>
      _optional('lists', () async {
        final values = await Future.wait([
          actions.getMyListsContainingMovie(userId, id),
          actions.getFriendsListsContainingMovie(userId, id),
        ]);
        return values;
      }, (value) {
        myListsContainingMovie = value[0] as List<MovieList>;
        friendsListsContainingMovie = value[1] as List<MovieFriendListEntry>;
      });

  @override
  void dispose() {
    _disposed = true;
    _sections.dispose();
    super.dispose();
  }
}
