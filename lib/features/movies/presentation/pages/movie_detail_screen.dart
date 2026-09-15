import 'package:flixie_app/features/movies/presentation/widgets/watch_provider_header.dart';
import 'package:flixie_app/features/movies/presentation/widgets/provider_tab_label.dart';
import 'package:flixie_app/features/sharing/presentation/media_chat_share.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_friend_activity_row.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart'
    show showSettingsEditDetailsSheet;
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_provider_link.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
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
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favourite_limit_sheet.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/models/friend_summary.dart';
import 'package:flixie_app/features/movies/presentation/widgets/cast_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_links_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/film_info_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/friend_activity_row.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/movies/presentation/widgets/genre_chip.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_reviews_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/similar_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/video_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_lists_section.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/analytics/recommendation_attribution.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.fromMovieMatch = false,
    this.source = DetailSource.unknown,
    this.recommendation,
  });

  final String movieId;
  final bool fromMovieMatch;
  final DetailSource source;
  final RecommendationAttribution? recommendation;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _FullScreenMoviePoster extends StatelessWidget {
  const _FullScreenMoviePoster({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final posterPath = movie.posterPath;
    final url = posterPath == null
        ? null
        : 'https://image.tmdb.org/t/p/original$posterPath';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Hero(
                tag: 'movie-poster-${movie.id}',
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: url == null
                      ? const Center(
                          child: Icon(
                            Icons.movie_outlined,
                            color: FlixieColors.medium,
                            size: 48,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: FlixieColors.primary,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: FlixieColors.medium,
                              size: 48,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton.filledTonal(
                tooltip: 'Close poster',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .65),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Text(
                movie.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieImageGridScreen extends StatelessWidget {
  const _MovieImageGridScreen({
    required this.movieTitle,
    required this.images,
  });

  final String movieTitle;
  final List<MovieImage> images;

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _MovieImageGalleryViewer(
            movieTitle: movieTitle,
            images: images,
            initialIndex: initialIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        foregroundColor: FlixieColors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$movieTitle photos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${images.length} images',
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700 ? 4 : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.25,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return Semantics(
                button: true,
                label: 'Open photo ${index + 1} of ${images.length}',
                child: InkWell(
                  onTap: () => _openViewer(context, index),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: image.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const SkeletonBox(borderRadius: 12),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: FlixieColors.surface,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: FlixieColors.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MovieImageGalleryViewer extends StatefulWidget {
  const _MovieImageGalleryViewer({
    required this.movieTitle,
    required this.images,
    required this.initialIndex,
  });

  final String movieTitle;
  final List<MovieImage> images;
  final int initialIndex;

  @override
  State<_MovieImageGalleryViewer> createState() =>
      _MovieImageGalleryViewerState();
}

class _MovieImageGalleryViewerState extends State<_MovieImageGalleryViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return InteractiveViewer(
                  key: ValueKey(image.path),
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: image.originalUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                          color: FlixieColors.primary,
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: FlixieColors.medium,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton.filledTonal(
                tooltip: 'Close photos',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .65),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              top: 14,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Text(
                widget.movieTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ListUpdateType { watchlist, watched, favorite }

enum FriendActivityTab { all, watched, watchlist, ratings, reviews, lists }

enum WatchProviderTab { stream, rent, buy }

enum MovieDetailTab { overview, reviews, activity, details }

class _MovieDetailHeroTokens {
  const _MovieDetailHeroTokens._();

  static const double pageHorizontalPadding = 8;
  static const double heroToWatchSectionGap = 14;
  static const double heroControlsTopInset = 2;
  static const double heroSurfaceTopPadding = 0;
  static const double heroSurfaceBottomPadding = 6;
  static const double heroTopScrimHeight = 112;

  static const double navButtonSize = 44;
  static const double navIconSize = 21;
  static const double navIconSizeMinimal = 20;
  static const double navButtonLightBgAlpha = 0.30;
  static const double navButtonDarkBgAlpha = 0.42;
  static const double navButtonDarkMinimalBgAlpha = 0.18;
  static const double navButtonBorderAlpha = 0.24;
  static const double navButtonMinimalBorderAlpha = 0.18;
  static const double navButtonShadowAlpha = 0.28;
  static const double navButtonMinimalShadowAlpha = 0.12;
  static const double navButtonBlurSigma = 12;
  static const double navButtonMinimalBlurSigma = 6;
  static const double navButtonBorderWidth = 0.85;
  static const double navButtonMinimalBorderWidth = 0.7;

  static const double posterCompactWidthFactor = 0.42;
  static const double posterRegularWidthFactor = 0.38;
  static const double posterMinWidth = 120;
  static const double posterMaxWidth = 144;
  static const double posterCornerRadius = 0;
  static const double posterRightRadius = 12;
  static const double posterAspectRatio = 2 / 3;

  static const double heroColumnGap = 12;
  static const double heroContentRightInset = 14;

  static const double textBlockGapCompact = 8;
  static const double textBlockGapRegular = 10;
  static const double genreTopGapCompact = 10;
  static const double genreTopGapRegular = 12;

  static const double titleCompact = 22;
  static const double titleRegular = 30;
  static const double titleWide = 36;
  static const double titleLineHeight = 1.03;
  static const double titleLetterSpacing = 0.05;

  static const double metadataCompact = 13;
  static const double metadataRegular = 15;
  static const double metadataAlpha = 0.92;
  static const double metadataLineHeight = 1.1;

  static const double taglineCompact = 14;
  static const double taglineRegular = 16;
  static const double taglineLineHeight = 1.18;

  static const double flixScoreHorizontalPadding = 11;
  static const double flixScoreVerticalPadding = 7;
  static const double flixScoreBackgroundAlpha = 0.48;
  static const double flixScoreBorderAlpha = 0.65;
  static const double flixScoreIconSize = 17;
  static const double flixScoreValueSize = 14;
  static const double flixScoreLabelSize = 12;
  static const double textActionRadius = 8;
  static const double textActionVerticalPadding = 3;
  static const double textActionIconCompact = 18;
  static const double textActionIconRegular = 22;
  static const double textActionLabelCompact = 10.5;
  static const double textActionLabelRegular = 13;
  static const double _sectionSpacing = 24;
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  Movie? _movie;
  List<Review> _reviews = [];
  List<SimilarMovie> _similar = [];
  List<MovieCastMember> _cast = [];
  MovieImages _movieImages = const MovieImages();
  bool get _movieImagesLoading => _sectionStates['images'] == 'loading';
  List<WatchProvider> _watchProviders = [];
  Set<int> _userProviderIds = {};
  Set<String> _userProviderMatchKeys = {};
  WatchProviderTab _watchProviderTab = WatchProviderTab.stream;
  MovieDetailTab _movieDetailTab = MovieDetailTab.overview;
  CrewMember? _director;
  List<String> _producers = [];
  List<String> _writers = [];
  bool _isLoading = true;
  String? _error;
  bool _inWatchlist = false;
  bool _isWatched = false;
  bool _isFavorite = false;
  int? _userRating;
  bool? _userRecommends;
  bool _isRatingLoading = false;
  ListUpdateType? _currentlyUpdating;
  List<MovieFriendActivity> _friendsActivity = [];
  FriendRecommendationResponse? _friendRecommendation;
  bool get _friendRecommendationLoading =>
      _sectionStates['friend recommendations'] == 'loading';
  Object? _friendRecommendationError;
  FriendSummaryResponse? _friendSummary;
  bool get _friendSummaryLoading =>
      _sectionStates['friend summary'] == 'loading';
  Object? _friendSummaryError;
  List<MovieList> _myListsContainingMovie = [];
  List<MovieFriendListEntry> _friendsListsContainingMovie = [];
  bool get _listsContainingMovieLoading => _sectionStates['lists'] == 'loading';
  List<MovieWatchEntry> _movieWatchHistory = [];
  bool get _watchHistoryLoading => _sectionStates['history'] == 'loading';
  FriendActivityTab _friendsActivityTab = FriendActivityTab.all;
  bool _showFullSynopsis = false;
  final _movieTabContentKey = GlobalKey();
  String? _heroControlPosterPath;
  Color _heroControlBackgroundColor = Colors.black
      .withValues(alpha: _MovieDetailHeroTokens.navButtonDarkBgAlpha);
  Color _heroControlIconColor = FlixieColors.white;
  Color _heroControlBorderColor = Colors.white
      .withValues(alpha: _MovieDetailHeroTokens.navButtonBorderAlpha);
  Color _heroControlShadowColor = Colors.black
      .withValues(alpha: _MovieDetailHeroTokens.navButtonShadowAlpha);
  bool _heroControlMinimal = false;
  static const List<Color> _kGenreChipColors = [
    Color(0xFF9B6CFF),
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.warning,
  ];
  bool _watchHistoryLoaded = false;
  int get _watchCount => _movieWatchHistory.length;

  // ---- Data loading ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.movieId);
    if (id != null && id > 0) {
      context.read<AnalyticsController?>()?.contentOpened(
            contentType: 'movie',
            contentId: id,
            source: widget.source.value,
          );
    }
    _load();
  }

  Future<void> _refresh() async {
    final id = int.tryParse(widget.movieId);
    if (id != null) context.read<MovieService>().evictMovie(id);
    await _load();
  }

  int _loadGeneration = 0;
  final Map<String, String> _sectionStates = {};
  final Map<String, Future<void> Function()> _sectionRetries = {};
  final Map<String, int> _sectionAttempts = {};

  @override
  void didUpdateWidget(covariant MovieDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieId != widget.movieId) {
      _movie = null;
      _isLoading = true;
      _load();
    }
  }

  Future<void> _optional<T>(
      String key, Future<T> Function() fetch, void Function(T) apply) async {
    final generation = _loadGeneration;
    final viewer = context.read<AuthProvider>().dbUser?.id;
    final attempt = (_sectionAttempts[key] ?? 0) + 1;
    _sectionAttempts[key] = attempt;
    bool current() =>
        mounted &&
        generation == _loadGeneration &&
        attempt == _sectionAttempts[key] &&
        viewer == context.read<AuthProvider>().dbUser?.id;
    if (!mounted) return;
    setState(() {
      _sectionStates[key] = 'loading';
      _sectionRetries[key] = () => _optional(key, fetch, apply);
    });
    try {
      final value = await fetch();
      if (!current()) return;
      setState(() {
        apply(value);
        _sectionStates.remove(key);
      });
    } catch (error) {
      if (!current()) return;
      apiLogger.w('Movie detail section $key failed: $error');
      setState(() => _sectionStates[key] = 'error');
    }
  }

  Widget _optionalSection(String key, String label, Widget child) {
    final state = _sectionStates[key];
    if (state == null) return child;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        if (state == 'loading') ...[
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, semanticsLabel: 'Loading $label')),
          const SizedBox(width: 12),
        ],
        Expanded(
            child: Text(
                state == 'loading' ? 'Loading $label…' : 'Couldn’t load $label',
                style: const TextStyle(color: FlixieColors.medium))),
        if (state == 'error')
          TextButton(
              onPressed: _sectionRetries[key],
              child:
                  Semantics(label: 'Retry $label', child: const Text('Retry'))),
      ]),
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final id = int.tryParse(widget.movieId);
    if (id == null || id <= 0) {
      setState(() {
        _error = 'Invalid movie ID.';
        _isLoading = false;
      });
      return;
    }
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    final service = context.read<MovieService>();
    setState(() {
      _error = null;
      _sectionStates.clear();
      _sectionRetries.clear();
      _similar = [];
      _cast = [];
      _director = null;
      _writers = [];
      _producers = [];
      _watchProviders = [];
      _movieImages = const MovieImages();
      _userRating = null;
      _userRecommends = null;
      _reviews = [];
      _friendsActivity = [];
      _friendSummary = null;
      _friendRecommendation = null;
      _movieWatchHistory = [];
      _watchHistoryLoaded = false;
      _myListsContainingMovie = [];
      _friendsListsContainingMovie = [];
      _userProviderIds = {};
      _userProviderMatchKeys = {};
    });
    final core = service.getMovieById(id);
    final optional = <Future<void>>[
      _optional('similar', () => service.getMovieRecommendations(id),
          (value) => _similar = value),
      _optional('credits', () => service.getMovieCredits(id), (credits) {
        _cast = credits.castMembers;
        _director = credits.crewMembers
            .where((crew) => crew.job == 'Director')
            .firstOrNull;
        _producers = <String>{
          ...credits.crewMembers
              .where((crew) => crew.job == 'Executive Producer')
              .map((crew) => crew.name),
          ...credits.crewMembers
              .where((crew) => crew.job == 'Producer')
              .map((crew) => crew.name),
        }.toList();
        _writers = credits.crewMembers
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
          (value) => _watchProviders = value),
      _optional('reviews', () => service.getMovieReviews(id, userId: userId),
          (value) => _reviews = value),
      _loadMovieImages(id),
      if (userId != null) ...[
        _optional(
            'your providers',
            () => WatchlistActionsController.instance
                .getUserWatchProviders(userId), (value) {
          _userProviderIds = value.map((provider) => provider.id).toSet();
          _userProviderMatchKeys =
              value.map((provider) => provider.matchKey).toSet();
        }),
        _optional('rating', () => service.getUserMovieRating(id, userId),
            (value) {
          _userRating = value.rating;
          _userRecommends = value.recommended;
        }),
        _optional('activity', () => service.getFriendsMovieActivity(id, userId),
            (value) => _friendsActivity = value),
        _loadWatchHistory(userId, id),
        _loadListsContainingMovie(userId, id),
        _loadFriendRecommendation(id),
        _loadFriendSummary(id),
      ],
    ];
    try {
      final movie = await core;
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _movie = movie;
        final user = auth.dbUser;
        _inWatchlist = user?.isMovieInWatchlist(id) ?? false;
        _isWatched = _watchHistoryLoaded
            ? _movieWatchHistory.isNotEmpty
            : (user?.isMovieWatched(id) ?? false);
        _isFavorite = user?.isMovieFavorite(id) ?? false;
        _isLoading = false;
      });
      _syncHeroControlContrast(movie);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
    // Pull-to-refresh completes only once its optional work has settled.
    // Rendering above does not wait for it.
    await Future.wait(optional);
  }

  Future<void> _loadMovieImages(int id) => _optional(
      'images',
      () => context.read<MovieService>().getMovieImages(id),
      (value) => _movieImages = value);

  Future<void> _loadWatchHistory(String userId, int id) => _optional(
          'history',
          () => WatchlistActionsController.instance
              .getMovieWatchHistory(userId, id), (value) {
        _movieWatchHistory = value;
        _watchHistoryLoaded = true;
        _isWatched = value.isNotEmpty;
      });

  Future<void> _loadFriendRecommendation(int id) => _optional(
      'friend recommendations',
      () => context.read<MovieService>().getFriendRecommendation(id),
      (value) => _friendRecommendation = value);

  Future<void> _loadFriendSummary(int id) => _optional(
      'friend summary',
      () => context.read<MovieService>().getFriendSummary(id),
      (value) => _friendSummary = value);

  Future<void> _loadListsContainingMovie(String userId, int id) =>
      _optional('lists', () async {
        final values = await Future.wait([
          WatchlistActionsController.instance
              .getMyListsContainingMovie(userId, id),
          WatchlistActionsController.instance
              .getFriendsListsContainingMovie(userId, id),
        ]);
        return values;
      }, (value) {
        _myListsContainingMovie = value[0] as List<MovieList>;
        _friendsListsContainingMovie = value[1] as List<MovieFriendListEntry>;
      });

  // ---- List Management ------------------------------------------------------

  Future<void> _toggleWatchlist({bool offerUndo = true}) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);

    if (user == null || movieId == null) return;

    setState(() => _currentlyUpdating = ListUpdateType.watchlist);

    try {
      final result = await (_inWatchlist
          ? WatchlistActionsController.instance
              .removeFromWatchlist(user.id, movieId)
          : WatchlistActionsController.instance
              .addToWatchlist(user.id, movieId));
      if (_inWatchlist) {
        await analytics.watchlistRemoved(
          contentType: 'movie',
          contentId: movieId,
          source: 'movie_detail',
        );
      } else {
        await analytics.watchlistAdded(
          contentType: 'movie',
          contentId: movieId,
          source: 'movie_detail',
        );
        final recommendation = widget.recommendation;
        if (recommendation != null) {
          await analytics.recommendationSaved(
            attribution: recommendation,
          );
        }
        await AppReviewService.recordMovieInteraction(
          user.id,
          hasCompletedSetup: user.completedSetup,
        );
      }

      // Successfully updated on server, toggle UI state and update user list
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _inWatchlist = !_inWatchlist;
          _currentlyUpdating = null;
        });

        // Keep existing entries, then append or remove the affected entry.
        final currentWatchlist =
            List<WatchlistMovie>.from(user.movieWatchlist ?? []);

        if (_inWatchlist) {
          // Added
          currentWatchlist.removeWhere((item) => item.movieId == movieId);
          final details = _movie;
          currentWatchlist.add(details == null
              ? result
              : WatchlistMovie.fromJson({
                  ...result.toJson(),
                  'movie': {
                    ...details.toJson(),
                    ...?result.movie?.toJson(),
                    'releaseDate':
                        result.movie?.releaseDate ?? details.releaseDate,
                    'runtime': result.movie?.runtime ?? details.runtime,
                    'voteAverage':
                        result.movie?.voteAverage ?? details.voteAverage,
                    'genres':
                        details.genres?.map((genre) => genre.name).toList() ??
                            [],
                  },
                }));
          authProvider.markActivityChanged();
          authProvider.updateUserList(movieWatchlist: currentWatchlist);
        } else {
          // Removed
          currentWatchlist.removeWhere((item) => item.movieId == movieId);
          authProvider.updateUserList(movieWatchlist: currentWatchlist);
          // Offer to mark as watched if not already
          if (offerUndo && !_isWatched && mounted) {
            final markWatched = await showFlixiePromptSheet<bool>(
              context: context,
              builder: (ctx) => FlixiePromptSheetContent(
                title: const Text('Did you watch it?',
                    style: TextStyle(color: FlixieColors.light)),
                content: const Text('Want to add this to your watched list?',
                    style: TextStyle(color: FlixieColors.medium)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No',
                        style: TextStyle(color: FlixieColors.medium)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Yes!',
                        style: TextStyle(color: FlixieColors.primary)),
                  ),
                ],
              ),
            );
            if (markWatched == true && mounted) {
              final committed = await _showLogWatchSheet();
              if (committed && mounted) {
                setState(() => _isWatched = true);
              }
            }
          }
        }
        if (mounted) {
          final savedState = _inWatchlist;
          ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.success,
            content: Text(
                savedState ? 'Added to watchlist' : 'Removed from watchlist'),
            action: offerUndo
                ? SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      if (mounted &&
                          _currentlyUpdating == null &&
                          _inWatchlist == savedState) {
                        _toggleWatchlist(offerUndo: false);
                      }
                    })
                : null,
          ));
        }
      }
    } catch (e) {
      logger.e('Error toggling watchlist: $e');
      if (mounted) {
        setState(() => _currentlyUpdating = null);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Couldn’t update your watchlist'),
              action: SnackBarAction(
                  label: 'Retry',
                  onPressed: () {
                    if (mounted && _currentlyUpdating == null) {
                      _toggleWatchlist();
                    }
                  })),
        );
      }
    }
  }

  Future<void> _toggleFavorite({bool offerUndo = true}) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);

    if (user == null || movieId == null) return;

    final activeFavouriteCount =
        (user.favoriteMovies ?? const <FavoriteMovie>[])
            .where((favorite) => favorite.removed != true)
            .length;
    if (!_isFavorite && activeFavouriteCount >= maxFavouriteMovies) {
      showFavouriteLimitPrompt(
        context,
        type: FavouriteLimitType.movie,
        onSpaceMade: _toggleFavorite,
      );
      return;
    }

    setState(() => _currentlyUpdating = ListUpdateType.favorite);
    try {
      final FavoriteMovie? addedFavorite;
      if (_isFavorite) {
        await WatchlistActionsController.instance
            .removeFromFavorites(user.id, movieId);
        await analytics.movieUnfavourited();
        addedFavorite = null;
      } else {
        addedFavorite = await WatchlistActionsController.instance
            .addToFavorites(user.id, movieId);
        await analytics.movieFavourited();
      }

      // Successfully updated on server, toggle UI state and update user list
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _isFavorite = !_isFavorite;
          _currentlyUpdating = null;
        });

        List<FavoriteMovie> updatedFavorites;
        if (_isFavorite) {
          // Added
          updatedFavorites =
              List<FavoriteMovie>.from(user.favoriteMovies ?? []);
          if (addedFavorite != null &&
              !updatedFavorites.any((f) => f.movieId == movieId)) {
            updatedFavorites.add(addedFavorite);
          }
          authProvider.markActivityChanged();
        } else {
          // Removed
          updatedFavorites = (user.favoriteMovies ?? [])
              .where((f) => f.movieId != movieId)
              .toList();
        }
        authProvider.updateUserList(favoriteMovies: updatedFavorites);
        final savedState = _isFavorite;
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.success,
          content: Text(
              savedState ? 'Added to favourites' : 'Removed from favourites'),
          action: offerUndo
              ? SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    if (mounted &&
                        _currentlyUpdating == null &&
                        _isFavorite == savedState) {
                      _toggleFavorite(offerUndo: false);
                    }
                  })
              : null,
        ));
      }
    } catch (e) {
      logger.e('Error toggling favorite: $e');
      if (mounted) {
        setState(() => _currentlyUpdating = null);
        if (isFavouriteLimitError(e)) {
          showFavouriteLimitPrompt(
            context,
            type: FavouriteLimitType.movie,
            onSpaceMade: _toggleFavorite,
          );
        } else {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
                type: FlixieToastType.error,
                content: const Text('Couldn’t update your favourites'),
                action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      if (mounted && _currentlyUpdating == null) {
                        _toggleFavorite();
                      }
                    })),
          );
        }
      }
    }
  }

  Future<void> _showAddToListSheet() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final movieId = int.tryParse(widget.movieId);
    if (movieId == null) return;
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToListSheet(
        movieId: movieId,
        movieTitle: _movie?.title,
        moviePosterPath: _movie?.posterPath,
        movieReleaseDate: _movie?.releaseDate,
        movieRuntimeMinutes: _movie?.runtime,
        movieRatingLabel: _movie?.voteAverage != null
            ? '★ ${_movie!.voteAverage!.toStringAsFixed(1)}'
            : null,
      ),
    );
    if (userId != null) {
      await _loadListsContainingMovie(userId, movieId);
    }
  }

  Future<bool> _showLogWatchSheet({MovieWatchEntry? entry}) async {
    final movieId = int.tryParse(widget.movieId);
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final movieService = context.read<MovieService>();
    final userId = authProvider.dbUser?.id;
    if (movieId == null || userId == null) return false;
    var didSubmit = false;
    var writeReview = false;
    double? reviewRating;
    bool? reviewRecommended;
    String? shareNote;
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        initial: entry,
        isRewatch: entry == null && _movieWatchHistory.isNotEmpty,
        previousWatch: entry == null && _movieWatchHistory.isNotEmpty
            ? _movieWatchHistory.first
            : null,
        showReviewOption: entry == null,
        onReviewSelected: (selected) => writeReview = selected,
        onSubmit: ({
          required String? watchedAt,
          required double? rating,
          required bool? recommended,
          required String? notes,
        }) async {
          try {
            reviewRating = rating;
            reviewRecommended = recommended;
            shareNote = notes;
            if (entry == null) {
              await WatchlistActionsController.instance.logMovieWatch(
                userId,
                LogMovieWatchRequest(
                  movieId: movieId,
                  watchedAt: watchedAt,
                  rating: rating,
                  recommended: recommended,
                  notes: notes,
                ),
              );
              // Also mark the movie as watched in the main watched list and
              // update local user state, then offer to remove from watchlist.
              final watchedResult = await WatchlistActionsController.instance
                  .addToWatched(userId, movieId);
              final user = authProvider.dbUser;
              final updatedWatched =
                  List<WatchedMovie>.from(user?.watchedMovies ?? []);
              updatedWatched.removeWhere((item) => item.movieId == movieId);
              updatedWatched.add(watchedResult ??
                  WatchedMovie(
                    id: '',
                    userId: userId,
                    movieId: movieId,
                    watchedAt: DateTime.now().toIso8601String(),
                  ));
              authProvider.updateUserList(watchedMovies: updatedWatched);
              authProvider.markActivityChanged();
              didSubmit = true;
              // Offer watchlist removal if applicable
              if (_inWatchlist && mounted) {
                final remove = await showFlixiePromptSheet<bool>(
                  context: context,
                  builder: (ctx) => FlixiePromptSheetContent(
                    title: const Text('Remove from Watchlist?',
                        style: TextStyle(color: FlixieColors.light)),
                    content: const Text(
                        "This movie is in your watchlist. Remove it now that you've watched it?",
                        style: TextStyle(color: FlixieColors.medium)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep it',
                            style: TextStyle(color: FlixieColors.medium)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove',
                            style: TextStyle(color: FlixieColors.primary)),
                      ),
                    ],
                  ),
                );
                if (remove == true && mounted) {
                  await WatchlistActionsController.instance
                      .removeFromWatchlist(userId, movieId);
                  await analytics.watchlistItemRemoved(source: 'movie_detail');
                  await analytics.movieRemovedFromWatchlist();
                  final updatedWatchlist =
                      (authProvider.dbUser?.movieWatchlist ?? [])
                          .where((item) => item.movieId != movieId)
                          .toList();
                  if (mounted) setState(() => _inWatchlist = false);
                  authProvider.updateUserList(
                      movieWatchlist: updatedWatchlist,
                      watchedMovies: updatedWatched);
                }
              }
            } else {
              await WatchlistActionsController.instance.updateMovieWatch(
                userId,
                entry.id,
                UpdateMovieWatchRequest(
                  watchedAt: watchedAt,
                  rating: rating,
                  recommended: recommended,
                  notes: notes,
                ),
              );
              didSubmit = true;
            }
            // Watch entries support ratings of their own. Make sure a rating
            // recorded here is also saved as the user's overall movie rating,
            // which powers the Rate action and the ratings list on their
            // profile. The API normally performs this sync; this check also
            // keeps older API deployments in step.
            if (rating != null) {
              final overallRating =
                  await movieService.getUserMovieRating(movieId, userId);
              if (overallRating.rating != rating.round() ||
                  overallRating.recommended != recommended) {
                await movieService.addMovieRating(
                  movieId,
                  userId,
                  rating.round(),
                  recommended,
                );
              }
            }
            if (entry == null) {
              await analytics.watchLogged(
                contentType: 'movie',
                contentId: movieId,
                source: 'movie_detail',
              );
              final recommendation = widget.recommendation;
              if (recommendation != null) {
                await analytics.recommendationWatched(
                  attribution: recommendation,
                );
              }
              if (rating != null) {
                await analytics.ratingAdded(
                  contentType: 'movie',
                  contentId: movieId,
                  source: recommendation?.source ?? 'movie_detail',
                  recommendation: recommendation,
                );
              }
            }
            await _loadWatchHistory(userId, movieId);
            // Evict the cache and re-fetch the movie so the updated
            // community rating (voteAverage / voteCount) is reflected.
            movieService.evictMovie(movieId);
            final updatedMovie =
                await movieService.getMovieById(movieId, userId: userId);
            if (mounted) {
              setState(() {
                _isWatched = true;
                _movie = updatedMovie;
                if (rating != null) _userRating = rating.round();
              });
              ScaffoldMessenger.of(context).showFlixieToast(
                FlixieToast(
                  type: FlixieToastType.success,
                  content: Text(
                      entry == null ? 'Watch logged' : 'Watch entry updated'),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
                  type: FlixieToastType.error,
                  content: Text('Unable to save watch entry: $e')));
            }
          }
        },
      ),
    );
    if (didSubmit) {
      final user = authProvider.dbUser;
      if (user != null) {
        await AppReviewService.recordMovieInteraction(
          user.id,
          hasCompletedSetup: user.completedSetup,
        );
      }
    }
    if (didSubmit && writeReview && mounted) {
      await _showWriteReviewSheet(
        context,
        initialRating: reviewRating,
        initialRecommended: reviewRecommended,
      );
    }
    if (didSubmit && reviewRating != null && mounted) {
      final user = authProvider.dbUser;
      final movie = _movie;
      if (user != null && movie != null) {
        promptShareCard(
          context,
          ShareCardData.rating(
            mediaType: ShareCardMediaType.movie,
            mediaId: movieId,
            title: movie.title,
            posterPath: movie.posterPath,
            user: user,
            rating: reviewRating!.round(),
            recommended: reviewRecommended,
            note: shareNote,
          ),
        );
      }
    }
    return didSubmit;
  }

  Future<void> _deleteWatchEntry(MovieWatchEntry entry) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final movieId = int.tryParse(widget.movieId);
    if (userId == null || movieId == null) return;
    try {
      await WatchlistActionsController.instance
          .deleteMovieWatch(userId, entry.id);
      if (!mounted) return;
      setState(() {
        _movieWatchHistory.removeWhere((watch) => watch.id == entry.id);
        _isWatched = _movieWatchHistory.isNotEmpty;
      });
      final auth = context.read<AuthProvider>();
      if (!_isWatched) {
        auth.updateUserList(
            watchedMovies: (auth.dbUser?.watchedMovies ?? [])
                .where((movie) => movie.movieId != movieId)
                .toList());
      }
      auth.markActivityChanged();
      await _loadWatchHistory(userId, movieId);
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.success,
            content: const Text('Watch entry deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: Text('Unable to delete watch entry: $e')));
      }
    }
  }

  // ---- Helpers --------------------------------------------------------------

  /// Formats the hero release date as year-only, or full date when released this year.
  String _formatHeroReleaseDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return '';

    if (dt.year == DateTime.now().year) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }

    return '${dt.year}';
  }

  /// Formats runtime in minutes to "Xh Ym".
  String _formatRuntime(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static const List<(FriendActivityTab, String)> _kFriendActivityTabs = [
    (FriendActivityTab.all, 'All'),
    (FriendActivityTab.watched, 'Watched'),
    (FriendActivityTab.watchlist, 'Watchlist'),
    (FriendActivityTab.ratings, 'Ratings'),
    (FriendActivityTab.reviews, 'Recommendations'),
    // TODO(release): Restore the Lists filter when list activity is returned
    // by the friends activity API.
  ];

  String _contentRating(Movie movie) {
    // TODO(laura): replace fallback with certification/country rating from API.
    return 'PG-13';
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: FlixieColors.background,
        body: SafeArea(child: MediaDetailScreenSkeleton()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: FlixieColors.background,
        appBar: AppBar(
          backgroundColor: FlixieColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: FlixieColors.light),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: FlixieColors.danger,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load movie',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _load();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final movie = _movie;
    if (movie == null) {
      return Scaffold(
        backgroundColor: FlixieColors.background,
        appBar: AppBar(
          backgroundColor: FlixieColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: FlixieColors.light),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Movie data is unavailable.',
            style: TextStyle(color: FlixieColors.medium),
          ),
        ),
      );
    }
    // Preserve the device text scale. Dense poster-led sections must reflow
    // or scroll rather than override a user's accessibility preference.
    return MediaQuery(
      data: MediaQuery.of(context),
      child: Scaffold(
        backgroundColor: FlixieColors.background,
        body: RefreshIndicator(
          color: FlixieColors.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildMovieIntro(context, movie),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: _MovieDetailHeroTokens.pageHorizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                          height: _MovieDetailHeroTokens.heroToWatchSectionGap),
                      _buildActionButtons(),
                      const SizedBox(height: 18),
                      _optionalSection('providers', 'watch providers',
                          _buildWhereToWatchSection(context)),
                      const SizedBox(height: 18),
                      _buildSynopsis(context, movie),
                      if (_friendsActivity.isNotEmpty ||
                          _friendSummaryLoading ||
                          _friendRecommendationLoading ||
                          _friendSummaryError != null ||
                          _friendRecommendationError != null) ...[
                        const SizedBox(height: 18),
                        _optionalSection('friend summary', 'friend summary',
                            _buildFriendSummarySection(context)),
                      ],
                      _optionalSection('activity', 'friend activity',
                          const SizedBox.shrink()),
                      _optionalSection('friend recommendations',
                          'friend recommendations', const SizedBox.shrink()),
                      _optionalSection('your providers',
                          'your streaming services', const SizedBox.shrink()),
                      _optionalSection(
                          'rating', 'your rating', const SizedBox.shrink()),
                      const SizedBox(height: 14),
                      _buildMovieDetailTabs(),
                      const SizedBox(height: 18),
                      Container(
                          key: _movieTabContentKey,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: KeyedSubtree(
                              key: ValueKey(_movieDetailTab),
                              child: _buildSelectedMovieTab(context, movie),
                            ),
                          )),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Hero top actions ----------------------------------------------------

  void _setHeroControlScheme({
    required bool darkPoster,
  }) {
    if (darkPoster) {
      _heroControlMinimal = true;
      _heroControlBackgroundColor = Colors.black.withValues(
          alpha: _MovieDetailHeroTokens.navButtonDarkMinimalBgAlpha);
      _heroControlIconColor = FlixieColors.white;
      _heroControlBorderColor = Colors.white.withValues(
          alpha: _MovieDetailHeroTokens.navButtonMinimalBorderAlpha);
      _heroControlShadowColor = Colors.black.withValues(
          alpha: _MovieDetailHeroTokens.navButtonMinimalShadowAlpha);
      return;
    }

    _heroControlMinimal = false;
    _heroControlBackgroundColor = Colors.white
        .withValues(alpha: _MovieDetailHeroTokens.navButtonLightBgAlpha);
    _heroControlIconColor = Colors.black.withValues(alpha: 0.88);
    _heroControlBorderColor = Colors.black.withValues(alpha: 0.18);
    _heroControlShadowColor = Colors.black.withValues(alpha: 0.18);
  }

  Future<void> _syncHeroControlContrast(Movie movie) async {
    final posterPath = movie.posterPath;
    if (_heroControlPosterPath == posterPath) return;
    _heroControlPosterPath = posterPath;

    if (posterPath == null || posterPath.isEmpty) {
      if (mounted) {
        setState(() => _setHeroControlScheme(darkPoster: false));
      }
      return;
    }

    final posterUrl = 'https://image.tmdb.org/t/p/w342$posterPath';
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(posterUrl),
        size: const Size(120, 180),
        maximumColorCount: 12,
      );

      if (!mounted || _heroControlPosterPath != posterPath) return;

      final swatch = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.darkVibrantColor?.color ??
          palette.mutedColor?.color;

      if (swatch == null) {
        setState(() => _setHeroControlScheme(darkPoster: false));
        return;
      }

      final isLightPoster =
          ThemeData.estimateBrightnessForColor(swatch) == Brightness.light;
      setState(() => _setHeroControlScheme(darkPoster: !isLightPoster));
    } catch (_) {
      if (!mounted || _heroControlPosterPath != posterPath) return;
      setState(() => _setHeroControlScheme(darkPoster: false));
    }
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
        button: true,
        label: 'Back',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: _MovieDetailHeroTokens.navButtonSize,
              height: _MovieDetailHeroTokens.navButtonSize,
              child: _heroControlChrome(
                child: Icon(
                  icon,
                  color: _heroControlIconColor,
                  size: _heroControlMinimal
                      ? _MovieDetailHeroTokens.navIconSizeMinimal
                      : _MovieDetailHeroTokens.navIconSize,
                ),
              ),
            ),
          ),
        ));
  }

  Widget _heroControlChrome({required Widget child}) {
    final blurSigma = _heroControlMinimal
        ? _MovieDetailHeroTokens.navButtonMinimalBlurSigma
        : _MovieDetailHeroTokens.navButtonBlurSigma;
    final borderWidth = _heroControlMinimal
        ? _MovieDetailHeroTokens.navButtonMinimalBorderWidth
        : _MovieDetailHeroTokens.navButtonBorderWidth;

    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _heroControlMinimal
                    ? _heroControlBackgroundColor
                    : _heroControlBackgroundColor.withValues(alpha: 0.78),
                _heroControlBackgroundColor,
              ],
            ),
            border: Border.all(
              color: _heroControlBorderColor,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: _heroControlShadowColor,
                blurRadius: _heroControlMinimal ? 4 : 10,
                offset: Offset(0, _heroControlMinimal ? 2 : 4),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildMovieIntro(BuildContext context, Movie movie) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final safeTop = MediaQuery.paddingOf(context).top;
        final heroContentTopPadding =
            safeTop + _MovieDetailHeroTokens.heroSurfaceTopPadding;
        final heroScrimHeight =
            safeTop + _MovieDetailHeroTokens.heroTopScrimHeight;
        final posterWidth = (constraints.maxWidth *
                (compact
                    ? _MovieDetailHeroTokens.posterCompactWidthFactor
                    : _MovieDetailHeroTokens.posterRegularWidthFactor))
            .clamp(_MovieDetailHeroTokens.posterMinWidth,
                _MovieDetailHeroTokens.posterMaxWidth);

        final stacked = constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: heroContentTopPadding,
                bottom: _MovieDetailHeroTokens.heroSurfaceBottomPadding,
              ),
              child: Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: posterWidth.toDouble(),
                    child: AspectRatio(
                      aspectRatio: _MovieDetailHeroTokens.posterAspectRatio,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(
                              _MovieDetailHeroTokens.posterCornerRadius),
                          topRight: Radius.circular(
                              _MovieDetailHeroTokens.posterRightRadius),
                          bottomLeft: Radius.circular(
                              _MovieDetailHeroTokens.posterCornerRadius),
                          bottomRight: Radius.circular(
                              _MovieDetailHeroTokens.posterRightRadius),
                        ),
                        child: Hero(
                          tag: 'movie-poster-${movie.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: movie.posterPath == null
                                  ? null
                                  : () => _showPosterViewer(movie),
                              child: movie.posterPath == null
                                  ? Container(
                                      color:
                                          FlixieColors.tabBarBackgroundFocused,
                                      child: const Icon(Icons.movie_outlined,
                                          color: FlixieColors.medium, size: 42),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w780${movie.posterPath}',
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      errorWidget: (_, __, ___) => const Center(
                                        child: Icon(Icons.movie_outlined,
                                            color: FlixieColors.medium,
                                            size: 42),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _MovieDetailHeroTokens.heroColumnGap),
                  Expanded(
                    flex: stacked ? 0 : 1,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: _MovieDetailHeroTokens.heroContentRightInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: compact ? 4 : 6,
                            ),
                            child: _buildTitleBlock(context, movie,
                                compact: compact),
                          ),
                          SizedBox(
                            height: compact
                                ? _MovieDetailHeroTokens.textBlockGapCompact
                                : _MovieDetailHeroTokens.textBlockGapRegular,
                          ),
                          _buildHeroFlixScoreBadge(context, movie),
                          SizedBox(
                            height: compact
                                ? _MovieDetailHeroTokens.textBlockGapCompact
                                : _MovieDetailHeroTokens.textBlockGapRegular,
                          ),
                          _buildHeroMetadataRow(movie, compact: compact),
                          if ((movie.tagline ?? '').isNotEmpty) ...[
                            SizedBox(
                              height: compact
                                  ? _MovieDetailHeroTokens.textBlockGapCompact
                                  : _MovieDetailHeroTokens.textBlockGapRegular,
                            ),
                            Text(
                              movie.tagline!,
                              style: TextStyle(
                                color: FlixieColors.light,
                                fontSize: compact
                                    ? _MovieDetailHeroTokens.taglineCompact
                                    : _MovieDetailHeroTokens.taglineRegular,
                                fontWeight: FontWeight.w700,
                                height:
                                    _MovieDetailHeroTokens.taglineLineHeight,
                              ),
                            ),
                          ],
                          SizedBox(
                            height: compact
                                ? _MovieDetailHeroTokens.genreTopGapCompact
                                : _MovieDetailHeroTokens.genreTopGapRegular,
                          ),
                          _buildGenrePills(
                            movie,
                            compact: compact,
                            maxItems: compact ? 2 : 3,
                          ),
                          SizedBox(
                            height: compact
                                ? _MovieDetailHeroTokens.textBlockGapCompact
                                : _MovieDetailHeroTokens.textBlockGapRegular,
                          ),
                          _buildHeroLinks(movie, compact: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: heroScrimHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: safeTop + _MovieDetailHeroTokens.heroControlsTopInset,
              left: _MovieDetailHeroTokens.pageHorizontalPadding,
              child: _heroIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.pop(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPosterViewer(Movie movie) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullScreenMoviePoster(movie: movie),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ---- Title + meta --------------------------------------------------------

  Widget _buildTitleBlock(BuildContext context, Movie movie,
      {bool compact = false}) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = compact
        ? _MovieDetailHeroTokens.titleCompact
        : (width < 700
            ? _MovieDetailHeroTokens.titleRegular
            : _MovieDetailHeroTokens.titleWide);

    return Text(
      movie.title,
      style: TextStyle(
        color: FlixieColors.white,
        fontSize: titleSize,
        fontWeight: FontWeight.w900,
        height: _MovieDetailHeroTokens.titleLineHeight,
        letterSpacing: _MovieDetailHeroTokens.titleLetterSpacing,
      ),
    );
  }

  Widget _buildHeroMetadataRow(Movie movie, {required bool compact}) {
    final year = _formatHeroReleaseDate(movie.releaseDate);
    final runtime = _formatRuntime(movie.runtime);
    final rating = _contentRating(movie);
    final metadata =
        [year, runtime, rating].where((item) => item.isNotEmpty).toList();

    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    final style = TextStyle(
      color: FlixieColors.light
          .withValues(alpha: _MovieDetailHeroTokens.metadataAlpha),
      fontSize: compact
          ? _MovieDetailHeroTokens.metadataCompact
          : _MovieDetailHeroTokens.metadataRegular,
      fontWeight: FontWeight.w700,
      height: _MovieDetailHeroTokens.metadataLineHeight,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var index = 0; index < metadata.length; index++) ...[
          if (index > 0) Text('•', style: style),
          Text(metadata[index], style: style),
        ],
      ],
    );
  }

  Widget _buildHeroFlixScoreBadge(BuildContext context, Movie movie) {
    final score = movie.voteAverage;
    final voteCount = movie.voteCount ?? 0;
    final hasScore = score != null && score > 0 && voteCount > 0;
    final color = !hasScore
        ? FlixieColors.medium
        : score >= 8
            ? FlixieColors.success
            : score >= 7
                ? FlixieColors.tertiary
                : score >= 6
                    ? FlixieColors.warning
                    : FlixieColors.danger;

    if (!hasScore) {
      return TextButton(
          onPressed: () => _showFlixScoreInfo(context),
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          child: const Text('No ratings yet'));
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showFlixScoreInfo(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _MovieDetailHeroTokens.flixScoreHorizontalPadding,
            vertical: _MovieDetailHeroTokens.flixScoreVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(
                alpha: _MovieDetailHeroTokens.flixScoreBackgroundAlpha),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: color.withValues(
                  alpha: _MovieDetailHeroTokens.flixScoreBorderAlpha),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                color: color,
                size: _MovieDetailHeroTokens.flixScoreIconSize,
              ),
              const SizedBox(width: 6),
              Text(
                hasScore ? score.toStringAsFixed(1) : '–',
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: _MovieDetailHeroTokens.flixScoreValueSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'FlixScore',
                style: TextStyle(
                    color: FlixieColors.primary,
                    fontSize: _MovieDetailHeroTokens.flixScoreLabelSize,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroLinks(Movie movie, {required bool compact}) {
    final videos = movie.videos ?? const [];
    final trailer = videos
        .where((video) =>
            video.videoTypeName.trim().toLowerCase() == 'trailer' &&
            video.key.trim().isNotEmpty)
        .firstOrNull;

    if (trailer == null) return const SizedBox.shrink();

    return _heroTextAction(
      icon: Icons.play_circle_outline_rounded,
      label: 'Watch trailer',
      iconColor: FlixieColors.danger,
      compact: compact,
      onTap: () => _openTrailer(trailer.youtubeUrl),
    );
  }

  Widget _heroTextAction({
    required IconData icon,
    required String label,
    Color iconColor = FlixieColors.light,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(_MovieDetailHeroTokens.textActionRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: _MovieDetailHeroTokens.textActionVerticalPadding),
        child: SizedBox(
          height: compact
              ? _MovieDetailHeroTokens.textActionIconCompact
              : _MovieDetailHeroTokens.textActionIconRegular,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: compact
                    ? _MovieDetailHeroTokens.textActionIconCompact
                    : _MovieDetailHeroTokens.textActionIconRegular,
              ),
              const SizedBox(width: 6),
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: compact
                        ? _MovieDetailHeroTokens.textActionLabelCompact
                        : _MovieDetailHeroTokens.textActionLabelRegular,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTrailer(String trailerUrl) async {
    final uri = Uri.tryParse(trailerUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not open this trailer')),
        );
      }
    }
  }

  // ---- Genre pills ---------------------------------------------------------

  Widget _buildGenrePills(Movie movie, {bool compact = false, int? maxItems}) {
    final genres = movie.genres;
    if (genres == null || genres.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleCount = maxItems ?? (compact ? 2 : genres.length);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: genres.take(visibleCount).toList().asMap().entries.map((entry) {
        return GenreChip(
          label: entry.value.name.toUpperCase(),
          color: _kGenreChipColors[entry.key % _kGenreChipColors.length],
          compact: true,
        );
      }).toList(),
    );
  }

  // ---- User Rating ----------------------------------------------------------

  Future<void> _setUserRating(int rating, bool? recommended,
      {bool offerUndo = true}) async {
    final previousRating = _userRating;
    final previousRecommendation = _userRecommends;
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    final movieId = int.tryParse(widget.movieId);
    if (user == null || movieId == null || _movie == null) return;

    setState(() => _isRatingLoading = true);
    try {
      final movieService = context.read<MovieService>();
      // Add rating and get updated vote average and count
      final response = await movieService.addMovieRating(
          movieId, user.id, rating, recommended);
      await analytics.ratingAdded(
        contentType: 'movie',
        contentId: movieId,
        source: widget.recommendation?.source ?? 'movie_detail',
        recommendation: widget.recommendation,
      );
      await AppReviewService.recordMovieInteraction(
        user.id,
        hasCompletedSetup: user.completedSetup,
      );

      // Extract updated vote data from response (safely parse types)
      final newVoteAverage = _parseDouble(response['voteAverage']);
      final newVoteCount = _parseInt(response['voteCount']);

      // Update the movie with new vote data
      final updatedMovie = _movie!.copyWith(
        voteAverage: newVoteAverage,
        voteCount: newVoteCount,
      );

      // Update cache with the new movie data
      movieService.updateCachedMovie(updatedMovie);

      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _userRating = rating;
          _userRecommends = recommended;
          _movie = updatedMovie;
          _isRatingLoading = false;
        });
        if (offerUndo && previousRating != null) {
          ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.success,
            content: const Text('Rating saved'),
            action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  if (mounted &&
                      !_isRatingLoading &&
                      _userRating == rating &&
                      _userRecommends == recommended) {
                    _setUserRating(previousRating, previousRecommendation,
                        offerUndo: false);
                  }
                }),
          ));
        } else {
          promptShareCard(
            context,
            ShareCardData.rating(
              mediaType: ShareCardMediaType.movie,
              mediaId: movieId,
              title: updatedMovie.title,
              posterPath: updatedMovie.posterPath,
              user: user,
              rating: rating,
              recommended: recommended,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to set rating: $e');
      if (mounted) {
        setState(() => _isRatingLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Couldn’t save your rating'),
          action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (mounted && !_isRatingLoading) {
                  _setUserRating(rating, recommended);
                }
              }),
        ));
      }
    }
  }

  void _showRatingSheet() {
    if (_sectionStates.containsKey('rating')) return;
    var selectedRating = _userRating;
    bool? recommended = _userRecommends;
    showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          color: FlixieColors.tabBarBackgroundFocused,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rate this movie',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Choose a score, then tell us whether you would recommend it.',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: List.generate(10, (i) {
                    final rating = i + 1;
                    final isSelected = selectedRating == rating;
                    return InkWell(
                      onTap: () => setSheetState(() {
                        selectedRating = rating;
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? FlixieColors.primary
                              : FlixieColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$rating',
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : FlixieColors.medium,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Would you recommend it? *',
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Choose Yes or No to save your rating.',
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Yes, recommend'),
                      selected: recommended == true,
                      onSelected: selectedRating == null
                          ? null
                          : (_) => setSheetState(() => recommended = true),
                    ),
                    ChoiceChip(
                      label: const Text("No, don't recommend"),
                      selected: recommended == false,
                      onSelected: selectedRating == null
                          ? null
                          : (_) => setSheetState(() => recommended = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedRating == null || recommended == null
                        ? null
                        : () {
                            final rating = selectedRating!;
                            Navigator.pop(ctx);
                            _setUserRating(rating, recommended);
                          },
                    child: const Text('Save rating'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Movie dashboard -----------------------------------------------------

  // Kept for the standalone dashboard treatment while the Reviews tab uses
  // the focused review feed layout.
  // ignore: unused_element
  Widget _buildMovieDashboard(BuildContext context, Movie movie) {
    final score = movie.voteAverage;
    final voteCount = movie.voteCount ?? 0;
    final hasCommunityRatings = voteCount > 0 && score != null && score > 0;
    final recentWatch =
        _movieWatchHistory.isNotEmpty ? _movieWatchHistory.first : null;
    final hasHistory = recentWatch != null;
    final watchDate = hasHistory
        ? _formatReadableDate(recentWatch.watchedAt)
        : 'Not watched yet';
    final statusLabel = _isWatched
        ? 'Watched $_watchCount ${_watchCount == 1 ? 'time' : 'times'}'
        : _inWatchlist
            ? 'On your watchlist'
            : 'Not tracked yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your movie dashboard',
                      style: TextStyle(
                        color: FlixieColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ratings, history, and your status in one place.',
                      style: TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'About FlixScore',
                onPressed: () => _showFlixScoreInfo(context),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: FlixieColors.medium,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;
              final tiles = [
                _DashboardTile(
                  title: 'FlixScore',
                  value: hasCommunityRatings
                      ? '${score.toStringAsFixed(1)}/10'
                      : '- /10',
                  icon: Icons.star_border_rounded,
                  color: Colors.deepOrangeAccent,
                  onTap: () => _showFlixScoreInfo(context),
                ),
                _DashboardTile(
                  title: 'Ratings',
                  value: _formatVoteCount(voteCount),
                  icon: Icons.people_outline_rounded,
                  color: FlixieColors.tertiary,
                  onTap: () => _showFlixScoreInfo(context),
                ),
                _DashboardTile(
                  title: 'Your rating',
                  value: _sectionStates['rating'] == 'loading'
                      ? 'Loading…'
                      : _userRating != null
                          ? '${_userRating!}/10'
                          : '+ Rate',
                  icon: Icons.star_rounded,
                  color: FlixieColors.warning,
                  onTap:
                      _isRatingLoading || _sectionStates.containsKey('rating')
                          ? null
                          : _showRatingSheet,
                ),
                _DashboardTile(
                  title: 'Your status',
                  value: statusLabel,
                  icon: _isWatched
                      ? Icons.check_circle_rounded
                      : _inWatchlist
                          ? Icons.bookmark_rounded
                          : Icons.radio_button_unchecked_rounded,
                  color: _isWatched
                      ? FlixieColors.success
                      : _inWatchlist
                          ? FlixieColors.warning
                          : FlixieColors.medium,
                ),
                _DashboardTile(
                  title: 'Last watched',
                  value: watchDate,
                  icon: Icons.schedule_rounded,
                  color: FlixieColors.light,
                ),
              ];

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tiles
                      .map(
                        (tile) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: tile,
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tiles
                    .map(
                      (tile) => SizedBox(
                        width: (constraints.maxWidth - 8) / 2,
                        child: tile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFlixScoreInfo(BuildContext context) {
    showFlixiePromptSheet<void>(
      context: context,
      builder: (context) => FlixiePromptSheetContent(
        title: const Text(
          'FLIXSCORE',
          style: TextStyle(
            color: FlixieColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community ratings from Flixie.',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Rating Guide:',
              style: TextStyle(
                color: FlixieColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '🔥 8.1+ · Loved\n'
              '😀 7.0-8.1 · Liked\n'
              '🙂 6.0-7.0 · Okay\n'
              '😐 5.0-6.0 · Meh\n'
              '😕 Below 5.0 · Disliked\n'
              'N/A · No ratings yet.',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // ---- Type parsing helpers ------------------------------------------------

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // ---- Synopsis ------------------------------------------------------------

  Widget _buildSynopsis(BuildContext context, Movie movie) {
    final text = movie.overview;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final sentenceEnd = RegExp(r'[.!?](?:\s|$)').firstMatch(text);
    final preview =
        sentenceEnd == null ? text : text.substring(0, sentenceEnd.start + 1);
    final showToggle = preview.length < text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Story'),
        const SizedBox(height: 8),
        Text(
          _showFullSynopsis ? text : preview,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            height: 1.48,
          ),
        ),
        if (showToggle) ...[
          const SizedBox(height: 7),
          GestureDetector(
            onTap: () => setState(() => _showFullSynopsis = !_showFullSynopsis),
            child: Text(
              _showFullSynopsis ? 'Show less' : 'Read more',
              style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (_director != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push(personDetailPath(
              _director!.id,
              source: DetailSource.personCredits,
              parentContentId: movie.id,
              parentContentType: 'movie',
            )),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12.5),
                children: [
                  const TextSpan(
                    text: 'Directed by ',
                    style: TextStyle(
                      color: FlixieColors.medium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: _director!.name,
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---- Watch request -------------------------------------------------------

  void _showWatchRequestSheet() {
    final auth = context.read<AuthProvider>();
    final friends = auth.cachedFriends?.friendships ?? [];
    final userId = auth.dbUser?.id;

    if (userId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MovieWatchRequestSheet(
        movieId: int.tryParse(widget.movieId),
        movieTitle: _movie?.title,
        moviePoster: _movie?.posterPath,
        requesterId: userId,
        friends: friends,
        fromMovieMatch: widget.fromMovieMatch,
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.success,
                  content: const Text('Watch plan sent!')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.error,
                  content: const Text('Failed to send watch plan')),
            );
          }
        },
      ),
    );
  }

  // ---- CTA buttons ---------------------------------------------------------

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWatchEntryStatusRow(),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              Expanded(
                child: _statusActionItem(
                  icon: _inWatchlist ? Icons.bookmark : Icons.bookmark_outline,
                  label: 'Watchlist',
                  color: FlixieColors.warning,
                  isActive: _inWatchlist,
                  isLoading: _currentlyUpdating == ListUpdateType.watchlist,
                  onTap: _currentlyUpdating != null ? null : _toggleWatchlist,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: _isFavorite ? Icons.favorite : Icons.favorite_outline,
                  label: 'Favourite',
                  color: FlixieColors.danger,
                  isActive: _isFavorite,
                  isLoading: _currentlyUpdating == ListUpdateType.favorite,
                  onTap: _currentlyUpdating != null ? null : _toggleFavorite,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: _myListsContainingMovie.isNotEmpty
                      ? Icons.playlist_add_check_rounded
                      : Icons.playlist_add_rounded,
                  label: 'List',
                  color: FlixieColors.secondary,
                  isActive: _myListsContainingMovie.isNotEmpty,
                  isLoading: _listsContainingMovieLoading,
                  onTap:
                      _currentlyUpdating != null ? null : _showAddToListSheet,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: Icons.group_add_outlined,
                  label: 'Plan',
                  color: FlixieColors.primary,
                  isActive: false,
                  isLoading: false,
                  onTap: _currentlyUpdating != null
                      ? null
                      : _showWatchRequestSheet,
                ),
              ),
              Expanded(
                child: _statusActionItem(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  color: const Color(0xFF5CC8FF),
                  isActive: true,
                  isLoading: false,
                  onTap: _movie == null
                      ? null
                      : () => MediaChatShare(context).show(ChatShareMedia(
                          id: _movie!.id,
                          title: _movie!.title,
                          posterPath: _movie!.posterPath)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The movie header always shows one watch-entry component. Its evidence and
  /// CTA change with the latest entry, rather than mixing a movie-level rating
  /// with a separate watch-history action.
  Widget _buildWatchEntryStatusRow() {
    if (_watchHistoryLoading) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Loading your watch history…'));
    }
    if (_sectionStates['history'] == 'error') {
      return TextButton.icon(
          onPressed: () {
            final user = context.read<AuthProvider>().dbUser;
            if (user != null && _movie != null) {
              _loadWatchHistory(user.id, _movie!.id);
            }
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry watch history'));
    }

    final entries = [..._movieWatchHistory]..sort((a, b) {
        final left = DateTime.tryParse(a.watchedAt ?? '') ?? DateTime(0);
        final right = DateTime.tryParse(b.watchedAt ?? '') ?? DateTime(0);
        return right.compareTo(left);
      });
    final latest = entries.isEmpty ? null : entries.first;
    final previousRated =
        entries.skip(1).where((entry) => entry.rating != null).firstOrNull;
    final latestRated = latest?.rating != null;
    final watchedCount = entries.length;
    final isRewatch = watchedCount > 1;
    final hasAnyRating = entries.any((entry) => entry.rating != null);
    final canInteract = _currentlyUpdating == null;

    final title = watchedCount == 0
        ? 'Not watched yet'
        : watchedCount == 1
            ? 'Watched once'
            : 'Watched $watchedCount times';
    final icon = watchedCount == 0
        ? Icons.history_rounded
        : isRewatch
            ? Icons.replay_rounded
            : Icons.check_rounded;
    const iconColor = FlixieColors.success;
    final iconBackground = watchedCount == 0
        ? FlixieColors.primary.withValues(alpha: .18)
        : FlixieColors.success.withValues(alpha: .12);

    final dateText = latest?.watchedAt == null
        ? (watchedCount == 0
            ? 'Start your watch history'
            : 'Watch date not saved')
        : _formatWatchDate(latest!.watchedAt);
    final watchDetailText = latestRated
        ? '${isRewatch ? 'Latest · ' : ''}$dateText'
        : watchedCount == 0
            ? 'Start your watch history'
            : isRewatch
                ? 'Latest · $dateText  Not rated'
                : '$dateText  Not rated';
    final ratingText =
        latestRated ? '★ ${latest!.rating!.toStringAsFixed(0)}/10' : null;
    final recommendationLabel = latest?.recommended == true
        ? 'Recommended'
        : latest?.recommended == false
            ? 'Wouldn’t recommend'
            : null;
    final recommendationIcon = latest?.recommended == true
        ? '👍'
        : latest?.recommended == false
            ? '👎'
            : null;

    void openHistory() {
      setState(() => _movieDetailTab = MovieDetailTab.activity);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _movieTabContentKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(target,
              alignment: .1, duration: const Duration(milliseconds: 250));
        }
      });
    }

    void logAgain() => _showLogWatchSheet();
    void rateLatest() => _showLogWatchSheet(entry: latest);

    final needsRating = watchedCount > 0 && !latestRated;
    final primaryLabel = watchedCount == 0
        ? 'Log watch'
        : needsRating
            ? (isRewatch ? 'Rate latest' : 'Add rating')
            : 'Log again';
    final primaryAction =
        watchedCount == 0 || latestRated ? logAgain : rateLatest;
    final primaryButton = FilledButton(
      onPressed: canInteract ? primaryAction : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(primaryLabel),
    );

    final latestRating = latest?.rating;
    final previousRating = previousRated?.rating;
    final previousComparison = isRewatch &&
            latestRating != null &&
            previousRating != null
        ? '${previousRating.toStringAsFixed(0)}/10 → ${latestRating.toStringAsFixed(0)}/10'
        : null;
    final delta = previousComparison == null
        ? null
        : latestRating!.round() - previousRating!.round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: watchedCount == 0 ? null : openHistory,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackAction = constraints.maxWidth < 326 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2;
              final details = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (ratingText != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Text(
                          ratingText,
                          style: const TextStyle(
                            color: FlixieColors.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (recommendationLabel != null) ...[
                          const SizedBox(width: 7),
                          const Text(
                            '·',
                            style: TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            recommendationLabel,
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recommendationIcon!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    watchDetailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
              final leading = Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: iconBackground, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 24),
              );
              final action = needsRating && !isRewatch
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      OutlinedButton(
                        onPressed: canInteract ? rateLatest : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Add rating'),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Log again',
                        onPressed: canInteract ? logAgain : null,
                        icon: const Icon(Icons.replay_rounded),
                      ),
                    ])
                  : primaryButton;

              return Column(mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  leading,
                  const SizedBox(width: 10),
                  Expanded(child: details),
                  if (!stackAction) ...[const SizedBox(width: 8), action],
                ]),
                if (stackAction) ...[
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
                if (isRewatch &&
                    (previousComparison != null || !hasAnyRating)) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                          left: BorderSide(
                              color: FlixieColors.primary, width: 2)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          previousComparison == null
                              ? 'Previous watches · No ratings yet'
                              : 'Previous rating',
                          style: const TextStyle(
                              color: FlixieColors.medium, fontSize: 13),
                        ),
                      ),
                      if (previousComparison != null)
                        Text(
                          '$previousComparison${delta == null || delta == 0 ? '' : delta > 0 ? '  ↑$delta' : '  ↓${delta.abs()}'}',
                          style: const TextStyle(
                              color: FlixieColors.warning,
                              fontWeight: FontWeight.w600),
                        ),
                    ]),
                  ),
                ],
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _statusActionItem({
    required IconData icon,
    required String label,
    String? badge,
    required Color color,
    required bool isActive,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    final iconColor = isActive ? color : FlixieColors.light;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: label == 'Favourite' || label == 'Watchlist' ? isActive : null,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 38,
                  height: 34,
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(iconColor),
                            ),
                          )
                        : Icon(icon, size: 27, color: iconColor),
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    badge ?? label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatchHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Watch History'),
        const SizedBox(height: 10),
        if (_watchHistoryLoading)
          const Center(child: CircularProgressIndicator())
        else if (_movieWatchHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('No watches logged yet.',
                  style: TextStyle(color: FlixieColors.medium)),
              TextButton.icon(
                  onPressed: () => _showLogWatchSheet(),
                  icon: const Icon(Icons.add),
                  label: const Text('Log watch')),
            ]),
          )
        else
          ..._movieWatchHistory.take(5).map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: FlixieColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        _formatWatchDate(entry.watchedAt),
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (entry.rating != null)
                            'Rating: ${entry.rating!.toStringAsFixed(0)}/10',
                          if (entry.notes != null && entry.notes!.isNotEmpty)
                            entry.notes!,
                        ].join(' • '),
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        iconColor: FlixieColors.light,
                        color: FlixieColors.tabBarBackgroundFocused,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showLogWatchSheet(entry: entry);
                            return;
                          }
                          _deleteWatchEntry(entry);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'Edit',
                              style: TextStyle(color: FlixieColors.light),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: FlixieColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  String _formatWatchDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return 'Unknown date';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatReadableDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return 'Unknown';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // Retained while the compact friend view replaces the old recommendation UI.
  // ignore: unused_element
  void _showAllFriendRecommendations(BuildContext context) {
    final data = _friendRecommendation;
    if (data == null) return;
    final watchedFriends = data.friends.where((f) => f.watched).toList();
    showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      backgroundColor: FlixieColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Friend Recommendations',
                    style: TextStyle(
                      color: FlixieColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${data.recommendPercent}% recommend',
                    style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(
                height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: watchedFriends.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, thickness: 1, color: FlixieColors.tabBarBorder),
                itemBuilder: (_, index) {
                  final f = watchedFriends[index];
                  final name = f.username;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor:
                          FlixieColors.primary.withValues(alpha: 0.18),
                      backgroundImage: f.avatarUrl != null
                          ? NetworkImage(f.avatarUrl!)
                          : null,
                      child: f.avatarUrl == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                  color: FlixieColors.primary,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    title: Text(name,
                        style: const TextStyle(color: FlixieColors.light)),
                    subtitle: f.rating != null
                        ? Text(
                            '${f.rating!.toStringAsFixed(1)} / 10',
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 12),
                          )
                        : null,
                    trailing: f.recommends
                        ? const Icon(Icons.thumb_up_rounded,
                            color: FlixieColors.success, size: 18)
                        : const Icon(Icons.thumb_down_rounded,
                            color: FlixieColors.danger, size: 18),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/friends/${f.userId}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Friend summary ----------------------------------------------------

  Widget _buildFriendSummarySection(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return const SizedBox.shrink();
    final movieId = int.tryParse(widget.movieId);
    final loading = _friendSummaryLoading || _friendRecommendationLoading;
    if (loading && _friendsActivity.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friendsActivity.isEmpty && _friendSummary?.friendCount != null) {
      return const SizedBox.shrink();
    }
    if (_friendsActivity.isEmpty &&
        (_friendSummaryError != null || _friendRecommendationError != null)) {
      return TextButton.icon(
        onPressed: movieId == null
            ? null
            : () {
                _loadFriendSummary(movieId);
                _loadFriendRecommendation(movieId);
              },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reload friend activity'),
      );
    }

    final activities = _friendsActivity;
    final watched = activities.where((item) => item.watched).length;
    final rated = activities.where((item) => item.rating != null).length;
    final recommended =
        activities.where((item) => item.recommended == true).length;
    final watchlisted = activities.where((item) => item.onWatchlist).length;
    final favourited = activities.where((item) => item.favorited).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Friends',
                style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (activities.length > 1)
              TextButton.icon(
                onPressed: () => _showAllFriendsActivity(context, activities),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                label: const Text('View all'),
                style: TextButton.styleFrom(
                  foregroundColor: FlixieColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        Text(
          '${activities.length} ${activities.length == 1 ? 'friend' : 'friends'} interacted',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 11),
        ),
        const SizedBox(height: 8),
        if (activities.length > 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: _friendPanelDecoration(),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: 58,
                    height: 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: activities
                          .take(3)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) => Positioned(
                                left: entry.key * 17,
                                top: 0,
                                child:
                                    _compactFriendAvatar(entry.value, size: 28),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                _friendStat(watched, 'watched'),
                _friendStat(rated, 'rated'),
                _friendStat(recommended, 'recommend'),
                _friendStat(watchlisted, 'watchlist'),
                _friendStat(favourited, 'favourite'),
              ],
            ),
          ),
        const SizedBox(height: 7),
        ...activities.take(3).map(_compactFriendRow),
      ],
    );
  }

  BoxDecoration _friendPanelDecoration() => BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      );

  Widget _friendStat(int value, String label) => Expanded(
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 9.5)),
          ],
        ),
      );

  Widget _compactFriendAvatar(MovieFriendActivity activity,
      {double size = 30}) {
    final hex =
        activity.iconColor?['hexCode']?.toString().replaceFirst('#', '');
    final value = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    final color = value == null ? FlixieColors.primary : Color(value);
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        color: FlixieColors.surface,
        shape: BoxShape.circle,
      ),
      child: ProfileAvatarView(
        avatar: activity.avatar,
        fallbackText: activity.username.isEmpty
            ? '?'
            : activity.username[0].toUpperCase(),
        fallbackColor: color,
        size: size - 3,
        profileBadges: activity.profileBadges,
      ),
    );
  }

  Widget _compactFriendRow(MovieFriendActivity activity) =>
      MediaFriendActivityRow(
          activity: activity,
          onTap: () => context.push('/friends/${activity.userId}'));

  Widget _buildMovieDetailTabs() {
    return Row(
        children: MovieDetailTab.values.map((tab) {
      final selected = _movieDetailTab == tab;
      return Expanded(
          child: Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                  onTap: () => setState(() => _movieDetailTab = tab),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: selected
                                    ? FlixieColors.primaryText
                                    : FlixieColors.tabBarBorder,
                                width: selected ? 3 : 1))),
                    alignment: Alignment.center,
                    child: Text(
                        switch (tab) {
                          MovieDetailTab.overview => 'Overview',
                          MovieDetailTab.reviews => 'Reviews',
                          MovieDetailTab.activity => 'My Activity',
                          MovieDetailTab.details => 'Details',
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: selected ? Colors.white : FlixieColors.light,
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500)),
                  ))));
    }).toList());
  }

  Widget _buildSelectedMovieTab(BuildContext context, Movie movie) {
    return switch (_movieDetailTab) {
      MovieDetailTab.overview => _tabContent([
          _buildTrailersSection(context, movie),
          _optionalSection(
              'credits', 'cast and crew', _buildTopCastSection(context)),
          _optionalSection(
              'images', 'images', _buildImagesSection(context, movie)),
          _optionalSection(
              'similar', 'similar films', _buildMoreLikeThisSection(context)),
        ]),
      MovieDetailTab.reviews => _tabContent([
          _optionalSection(
              'reviews', 'reviews', _buildUserReviewsSection(context)),
        ]),
      MovieDetailTab.activity => _tabContent([
          _optionalSection(
              'history', 'watch history', _buildWatchHistorySection(context)),
          _optionalSection('lists', 'lists', _buildListsSection(context)),
        ]),
      MovieDetailTab.details => _tabContent([
          FilmInfoCard(
            director: null,
            writers: _writers,
            producers: _producers,
            movie: movie,
          ),
          ExternalLinksSection(movie: movie),
        ]),
    };
  }

  Widget _tabContent(List<Widget> sections) {
    final visibleSections = sections
        .where((section) => !(section is SizedBox &&
            section.child == null &&
            section.width == 0 &&
            section.height == 0))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visibleSections.length; index++) ...[
          if (index > 0)
            const SizedBox(height: _MovieDetailHeroTokens._sectionSpacing),
          visibleSections[index],
        ],
      ],
    );
  }

  // ---- Friends activity --------------------------------------------------

  // Retained for the full filtered activity treatment if it is restored later.
  // ignore: unused_element
  Widget _buildFriendsActivityContent(BuildContext context) {
    final filtered = _filteredFriendsActivity();
    final yourActivityBadges = _buildYourActivityBadges();
    final showYourActivityFooter = yourActivityBadges.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity',
          style: TextStyle(
            color: FlixieColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kFriendActivityTabs.map((tab) {
              final selected = _friendsActivityTab == tab.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _friendsActivityTab = tab.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? FlixieColors.primary.withValues(alpha: 0.22)
                          : FlixieColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? FlixieColors.primary.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      tab.$2,
                      style: TextStyle(
                        color: selected
                            ? FlixieColors.primary
                            : FlixieColors.light,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (filtered.isEmpty)
              Text(
                _friendsActivity.isEmpty
                    ? 'No friend activity yet for this movie.'
                    : 'No ${_friendTabLabel(_friendsActivityTab).toLowerCase()} activity yet.',
                style: const TextStyle(color: FlixieColors.medium),
              )
            else
              Column(
                children: filtered
                    .take(3)
                    .map((a) => FriendActivityRow(activity: a))
                    .toList(growable: false),
              ),
            if (filtered.length > 3) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showAllFriendsActivity(context, filtered),
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: Text('View all ${filtered.length} activities'),
                ),
              ),
            ],
            if (showYourActivityFooter) ...[
              if (filtered.isNotEmpty) const SizedBox(height: 4),
              const Divider(
                height: 20,
                thickness: 1,
                color: FlixieColors.tabBarBorder,
              ),
              const Text(
                'Your activity',
                style: TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: yourActivityBadges,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _showAllFriendsActivity(
    BuildContext context,
    List<MovieFriendActivity> activities,
  ) {
    var selectedTab = FriendActivityTab.all;
    var query = '';
    final watchedCount = activities.where((item) => item.watched).length;
    final ratedCount = activities.where((item) => item.rating != null).length;
    final recommendCount =
        activities.where((item) => item.recommended == true).length;
    final watchlistCount = activities.where((item) => item.onWatchlist).length;
    final favouritedCount = activities.where((item) => item.favorited).length;

    return showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final visible = activities.where((activity) {
            final matchesQuery = query.isEmpty ||
                activity.username.toLowerCase().contains(query);
            final matchesTab = switch (selectedTab) {
              FriendActivityTab.all => true,
              FriendActivityTab.watched => activity.watched,
              FriendActivityTab.watchlist => activity.onWatchlist,
              FriendActivityTab.ratings => activity.rating != null,
              FriendActivityTab.reviews => activity.recommended == true,
              FriendActivityTab.lists => true,
            };
            return matchesQuery && matchesTab;
          }).toList(growable: false);
          final tabs = <(FriendActivityTab, String, int)>[
            (FriendActivityTab.all, 'All', activities.length),
            (FriendActivityTab.watched, 'Watched', watchedCount),
            (FriendActivityTab.ratings, 'Rated', ratedCount),
            (FriendActivityTab.reviews, 'Recommend', recommendCount),
            (FriendActivityTab.watchlist, 'Watchlist', watchlistCount),
          ];

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            expand: false,
            builder: (context, controller) => Container(
              decoration: const BoxDecoration(
                color: FlixieColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: FlixieColors.medium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Friends',
                            style: TextStyle(
                              color: FlixieColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${activities.length} ${activities.length == 1 ? 'friend' : 'friends'} interacted with this movie',
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: _friendPanelDecoration(),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            height: 34,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ...activities
                                    .take(3)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) => Positioned(
                                          left: entry.key * 20,
                                          child: _compactFriendAvatar(
                                              entry.value,
                                              size: 34),
                                        )),
                                if (activities.length > 3)
                                  Positioned(
                                    left: 58,
                                    child: Container(
                                      width: 31,
                                      height: 31,
                                      margin: const EdgeInsets.all(1.5),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: FlixieColors.surfaceElevated,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: FlixieColors.medium),
                                      ),
                                      child: Text(
                                        '+${activities.length - 3}',
                                        style: const TextStyle(
                                          color: FlixieColors.light,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _friendStat(watchedCount, 'watched'),
                          _friendStat(ratedCount, 'rated'),
                          _friendStat(recommendCount, 'recommend'),
                          _friendStat(watchlistCount, 'watchlist'),
                          _friendStat(favouritedCount, 'favourite'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      onChanged: (value) => setSheetState(
                        () => query = value.trim().toLowerCase(),
                      ),
                      style: const TextStyle(color: FlixieColors.white),
                      decoration: InputDecoration(
                        hintText: 'Search friends',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor:
                            FlixieColors.background.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: tabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (_, index) {
                        final tab = tabs[index];
                        final selected = selectedTab == tab.$1;
                        return ChoiceChip(
                          selected: selected,
                          showCheckmark: false,
                          label: Text('${tab.$2}  ${tab.$3}'),
                          onSelected: (_) =>
                              setSheetState(() => selectedTab = tab.$1),
                          selectedColor: FlixieColors.primary,
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: selected
                                ? FlixieColors.primary
                                : FlixieColors.medium.withValues(alpha: 0.5),
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? FlixieColors.white
                                : FlixieColors.light,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: FlixieColors.tabBarBorder),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(
                            child: Text('No matching friends',
                                style: TextStyle(color: FlixieColors.medium)),
                          )
                        : ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                            itemCount: visible.length,
                            itemBuilder: (_, index) =>
                                _compactFriendRow(visible[index]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<MovieFriendActivity> _filteredFriendsActivity() {
    return _friendsActivity.where((activity) {
      switch (_friendsActivityTab) {
        case FriendActivityTab.all:
          return true;
        case FriendActivityTab.watched:
          return activity.watched;
        case FriendActivityTab.watchlist:
          return activity.onWatchlist;
        case FriendActivityTab.ratings:
          return activity.rating != null;
        case FriendActivityTab.reviews:
          return activity.recommended != null;
        case FriendActivityTab.lists:
          return false;
      }
    }).toList(growable: false);
  }

  List<Widget> _buildYourActivityBadges() {
    final badges = <Widget>[];
    if (_isFavorite) {
      badges.add(_buildYourActivityChip(
        icon: Icons.favorite,
        label: 'In favourites',
        color: Colors.redAccent,
      ));
    }
    if (_isWatched) {
      badges.add(_buildYourActivityChip(
        icon: Icons.check_circle,
        label: 'Watched',
        color: FlixieColors.success,
      ));
    }
    if (_inWatchlist) {
      badges.add(_buildYourActivityChip(
        icon: Icons.bookmark,
        label: 'In watchlist',
        color: FlixieColors.warning,
      ));
    }
    if (_userRating != null) {
      badges.add(_buildYourActivityChip(
        icon: Icons.star_rounded,
        label: '${_userRating!}/10',
        color: FlixieColors.tertiary,
      ));
    }
    if (_userRecommends != null) {
      badges.add(_buildYourActivityChip(
        icon: _userRecommends!
            ? Icons.thumb_up_alt_rounded
            : Icons.thumb_down_alt_rounded,
        label: _userRecommends! ? 'Recommended' : 'Not recommended',
        color: _userRecommends! ? FlixieColors.success : FlixieColors.medium,
      ));
    }
    return badges;
  }

  Widget _buildYourActivityChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildYourListsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Your Lists'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: _listsContainingMovieLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _myListsContainingMovie.isEmpty
                          ? "This movie isn't in any of your lists yet."
                          : 'This movie is in ${_myListsContainingMovie.length} of your lists',
                      style: const TextStyle(color: FlixieColors.medium),
                    ),
                    if (_myListsContainingMovie.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._myListsContainingMovie.map(
                        (list) => Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(list.name),
                            subtitle: Text('${list.movieCount ?? 0} film(s)'),
                            trailing: const Icon(
                              Icons.check_circle,
                              color: FlixieColors.primary,
                              size: 18,
                            ),
                            onTap: () => context.push(
                              '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&owner=${Uri.encodeComponent(list.userId ?? '')}',
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showAddToListSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Add to List'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildListsSection(BuildContext context) {
    final ownLists = _myListsContainingMovie
        .map((list) => MediaDetailListItem(
              id: list.id,
              name: list.name,
              visibility: list.visibility,
              posterUrls: list.previewPosterUrls,
              itemCount: list.itemCount ??
                  (list.movieCount ?? 0) + (list.showCount ?? 0),
              ownerId: list.userId,
            ))
        .toList(growable: false);
    final friendLists = _friendsListsContainingMovie
        .map((entry) => MediaDetailListItem(
              id: entry.listId,
              name: entry.listName,
              visibility: entry.visibility ?? 'PUBLIC',
              posterUrls: entry.previewPosterUrls,
              itemCount: entry.movieCount ?? 0,
              ownerId: entry.friendUserId,
              ownerUsername: entry.friendName,
              ownerAvatar: entry.friendAvatar,
            ))
        .toList(growable: false);

    return MediaListsSection(
      ownLists: ownLists,
      friendLists: friendLists,
      loading: _listsContainingMovieLoading,
      itemLabel: 'films',
      onEdit: _showAddToListSheet,
      onSeeAll: () => context.push('/movie-lists'),
      onOpenList: (item) => context.push(
        '/movie-lists/${item.id}'
        '?name=${Uri.encodeComponent(item.name)}'
        '&owner=${Uri.encodeComponent(item.ownerId ?? '')}',
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFriendsListsSection(BuildContext context) {
    final totalFriends = _friendsListsContainingMovie
        .map((entry) => entry.friendUserId)
        .toSet()
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Friends Lists'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: _listsContainingMovieLoading
              ? const Center(child: CircularProgressIndicator())
              : _friendsListsContainingMovie.isEmpty
                  ? const Text(
                      "None of your friends have added this to a list yet.",
                      style: TextStyle(color: FlixieColors.medium),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This movie is in $totalFriends friends\' lists',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._friendsListsContainingMovie.take(6).map(
                              (entry) => Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: ProfileAvatarView(
                                    avatar: entry.friendAvatar,
                                    fallbackText: (entry.friendName.isNotEmpty
                                            ? entry.friendName[0]
                                            : '?')
                                        .toUpperCase(),
                                    fallbackColor: FlixieColors.primary,
                                    size: 40,
                                  ),
                                  title: Text(
                                    "${entry.friendName} · ${entry.listName}",
                                    style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle:
                                      Text('${entry.movieCount ?? 0} films'),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: FlixieColors.medium,
                                  ),
                                  onTap: () => context.push(
                                    '/movie-lists/${entry.listId}'
                                    '?name=${Uri.encodeComponent(entry.listName)}'
                                    '&owner=${Uri.encodeComponent(entry.friendUserId)}',
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        color: FlixieColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
  }

  String _friendTabLabel(FriendActivityTab tab) {
    return _kFriendActivityTabs
            .where((entry) => entry.$1 == tab)
            .map((entry) => entry.$2)
            .firstOrNull ??
        'Activity';
  }

  // ---- Photos -------------------------------------------------------------

  Widget _buildImagesSection(BuildContext context, Movie movie) {
    if (_movieImagesLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Photos'),
          const SizedBox(height: 10),
          const SizedBox(
            height: 126,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  SkeletonBox(width: 224, height: 126, borderRadius: 14),
                  SizedBox(width: 10),
                  SkeletonBox(width: 224, height: 126, borderRadius: 14),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final images = _movieImages.gallery;
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'Photos'),
            TextButton(
              onPressed: () => _openImageGrid(movie, images),
              child: Text(
                'See all (${images.length})',
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final image = images[index];
              final width = (126 * image.aspectRatio).clamp(84.0, 224.0);
              return Semantics(
                button: true,
                label: 'Open photo ${index + 1} of ${images.length}',
                child: InkWell(
                  onTap: () => _openImageGallery(movie, images, index),
                  borderRadius: BorderRadius.circular(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: image.thumbnailUrl,
                      width: width,
                      height: 126,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => SkeletonBox(
                        width: width,
                        height: 126,
                        borderRadius: 14,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: width,
                        height: 126,
                        color: FlixieColors.surface,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: FlixieColors.medium,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openImageGallery(
    Movie movie,
    List<MovieImage> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _MovieImageGalleryViewer(
            movieTitle: movie.title,
            images: images,
            initialIndex: initialIndex,
          ),
        ),
      ),
    );
  }

  void _openImageGrid(Movie movie, List<MovieImage> images) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MovieImageGridScreen(
          movieTitle: movie.title,
          images: images,
        ),
      ),
    );
  }

  // ---- Trailers -----------------------------------------------------------

  Widget _buildTrailersSection(BuildContext context, Movie movie) {
    final videos = movie.videos;
    if (videos == null || videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'Trailers'),
            if (videos.length > 1)
              TextButton(
                onPressed: () => _showAllTrailersSheet(context, videos),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: FlixieColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => VideoCard(video: videos[i]),
          ),
        ),
      ],
    );
  }

  void _showAllTrailersSheet(BuildContext context, List<dynamic> videos) {
    showModalBottomSheet(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: FlixieColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            itemCount: videos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => VideoCard(video: videos[i]),
          ),
        ),
      ),
    );
  }

  // ---- Where to watch ------------------------------------------------------

  Widget _buildWhereToWatchSection(BuildContext context) {
    final providers = _providersForTab(_watchProviderTab);
    final hasOptions =
        WatchProviderTab.values.any((tab) => _providersForTab(tab).isNotEmpty);
    final region =
        context.watch<AuthProvider>().dbUser?.watchProviderRegion ?? 'GB';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WatchProviderHeader(
          region: region,
          onChange: () async {
            await showSettingsEditDetailsSheet(context);
            if (mounted) await _load();
          }),
      if (hasOptions)
        Row(
            children: WatchProviderTab.values
                .map((tab) => Expanded(child: _watchProviderTabButton(tab)))
                .toList()),
      for (final provider in providers.take(3))
        _buildCompactProviderCard(provider),
      if (providers.isEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
                hasOptions
                    ? 'No ${_providerTabLabel(_watchProviderTab).toLowerCase()} options listed. Check the other options above.'
                    : 'No watch options listed yet.',
                style: const TextStyle(color: FlixieColors.light))),
      if (providers.length > 3)
        TextButton(
            onPressed: () => _showAllProviderOptions(providers),
            child: Text(
                'See all ${providers.length} ${_providerTabLabel(_watchProviderTab).toLowerCase()} options')),
    ]);
  }

  Widget _watchProviderTabButton(WatchProviderTab tab) {
    final selected = _watchProviderTab == tab;
    return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _watchProviderTab = tab),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: selected
                            ? FlixieColors.primaryText
                            : FlixieColors.tabBarBorder,
                        width: selected ? 3 : 1))),
            alignment: Alignment.center,
            child: ProviderTabLabel(
                label: _providerTabLabel(tab),
                count: _providersForTab(tab).length,
                selected: selected),
          ),
        ));
  }

  String _providerTabLabel(WatchProviderTab tab) => switch (tab) {
        WatchProviderTab.stream => 'Stream',
        WatchProviderTab.rent => 'Rent',
        WatchProviderTab.buy => 'Buy',
      };

  List<WatchProvider> _providersForTab(WatchProviderTab tab) {
    final matching = switch (tab) {
      WatchProviderTab.stream =>
        _watchProviders.where((provider) => provider.isStreaming),
      WatchProviderTab.rent =>
        _watchProviders.where((provider) => provider.isRental),
      WatchProviderTab.buy =>
        _watchProviders.where((provider) => provider.isPurchase),
    };
    return _sortedProviders(
      _dedupeProviders(matching),
      prioritiseSavedProviders: tab == WatchProviderTab.stream,
    );
  }

  Widget _buildCompactProviderCard(WatchProvider provider) {
    final owned = _isUserProvider(provider) &&
        _watchProviderTab == WatchProviderTab.stream;
    final label = _watchProviderTab == WatchProviderTab.rent
        ? 'Available to rent'
        : _watchProviderTab == WatchProviderTab.buy
            ? 'Available to buy'
            : owned
                ? 'Your subscription'
                : provider.isAddOn
                    ? 'Separate add-on required'
                    : 'Subscription required';
    return WatchProviderLink(
        provider: provider,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: FlixieColors.tabBarBorder))),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: owned
                            ? FlixieColors.success
                            : FlixieColors.tabBarBorder,
                        width: owned ? 2 : 1)),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: provider.logoPath.isEmpty
                        ? const Icon(Icons.tv, color: FlixieColors.light)
                        : CachedNetworkImage(
                            imageUrl: provider.logoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(Icons.tv,
                                color: FlixieColors.light)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(provider.providerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          color:
                              owned ? FlixieColors.success : FlixieColors.light,
                          fontSize: 12)),
                ])),
            if (owned)
              const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Icon(Icons.check_circle,
                      color: FlixieColors.success, size: 20)),
            if (provider.verifiedWatchUri != null)
              const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.open_in_new,
                      color: FlixieColors.primaryText, size: 18)),
          ]),
        ));
  }

  void _showAllProviderOptions(List<WatchProvider> providers) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints.tightFor(width: MediaQuery.sizeOf(context).width),
      backgroundColor: FlixieColors.background,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8),
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 4, 16, 24 + MediaQuery.paddingOf(sheetContext).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_providerTabLabel(_watchProviderTab)} options',
                    style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Column(
                  children: providers.map(_buildCompactProviderCard).toList(),
                ),
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Availability by JustWatch · Opens TMDB',
                        style: TextStyle(
                            color: FlixieColors.light, fontSize: 12))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Iterable<WatchProvider> _dedupeProviders(Iterable<WatchProvider> providers) {
    final byId = <int, WatchProvider>{};
    for (final provider in providers) {
      byId.putIfAbsent(provider.id, () => provider);
    }
    return byId.values;
  }

  List<WatchProvider> _sortedProviders(
    Iterable<WatchProvider> providers, {
    required bool prioritiseSavedProviders,
  }) {
    return providers.toList()
      ..sort((a, b) {
        if (!prioritiseSavedProviders) {
          return a.displayPriority.compareTo(b.displayPriority);
        }
        final aMatches = _isUserProvider(a);
        final bMatches = _isUserProvider(b);
        if (aMatches != bMatches) return aMatches ? -1 : 1;
        return a.displayPriority.compareTo(b.displayPriority);
      });
  }

  bool _isUserProvider(WatchProvider provider) =>
      _userProviderIds.contains(provider.id) ||
      _userProviderMatchKeys.contains(provider.matchKey);

  // ---- Top cast ------------------------------------------------------------

  void _showAllCast(BuildContext context) {
    showModalBottomSheet(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllCastSheet(
        cast: _cast,
        parentContentId: int.parse(widget.movieId),
      ),
    );
  }

  Widget _buildTopCastSection(BuildContext context) {
    if (_cast.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'Top Cast'),
            TextButton(
              onPressed: () => _showAllCast(context),
              child: const Row(
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: FlixieColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: CastCard.heightFor(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _cast.length > 6 ? 6 : _cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) => CastCard(
              member: _cast[i],
              parentContentId: int.parse(widget.movieId),
              parentContentType: 'movie',
            ),
          ),
        ),
      ],
    );
  }

  // ---- Write review -------------------------------------------------------

  Future<void> _showWriteReviewSheet(
    BuildContext context, {
    double? initialRating,
    bool? initialRecommended,
  }) async {
    final user = context.read<AuthProvider>().dbUser;
    if (user == null) return;
    final movieId = int.tryParse(widget.movieId);
    if (movieId == null) return;

    await showModalBottomSheet<Review>(
      useSafeArea: true,
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WriteReviewSheet(
        movieId: movieId,
        userId: user.id,
        initialRating: initialRating,
        initialRecommended: initialRecommended,
        onSubmitted: (review) {
          final auth = context.read<AuthProvider>();
          setState(() => _reviews = [review, ..._reviews]);
          auth.invalidateCachedReviews();
          auth.markActivityChanged();
        },
      ),
    );
  }

  // ---- User reviews --------------------------------------------------------

  Widget _buildUserReviewsSection(BuildContext context) => MediaReviewsSection(
        reviews: _reviews,
        currentUserId: context.read<AuthProvider>().dbUser?.id,
        onWriteReview: () => _showWriteReviewSheet(context),
      );

  // ---- More like this ------------------------------------------------------

  Widget _buildMoreLikeThisSection(BuildContext context) {
    if (_similar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'More like this'),
        const SizedBox(height: 8),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SimilarMovieCard(movie: _similar[i]),
          ),
        ),
      ],
    );
  }
}

class _AllCastSheet extends StatefulWidget {
  const _AllCastSheet({required this.cast, required this.parentContentId});

  final List<MovieCastMember> cast;
  final int parentContentId;

  @override
  State<_AllCastSheet> createState() => _AllCastSheetState();
}

class _AllCastSheetState extends State<_AllCastSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _sortByName = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MovieCastMember> get _filteredCast {
    final query = _query.trim().toLowerCase();
    final cast = (query.isEmpty
            ? widget.cast
            : widget.cast.where((member) {
                return member.name.toLowerCase().contains(query) ||
                    member.character.toLowerCase().contains(query);
              }))
        .toList();
    if (_sortByName) {
      cast.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      cast.sort((a, b) => a.order.compareTo(b.order));
    }
    return cast;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCast;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: FlixieColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cast',
                          style: TextStyle(
                            color: FlixieColors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.cast.length} cast members',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: FlixieColors.light),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: FlixieColors.white),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search actor or character',
                  hintStyle: const TextStyle(color: FlixieColors.medium),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: FlixieColors.medium),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded,
                              color: FlixieColors.medium),
                        ),
                  filled: true,
                  fillColor: FlixieColors.surface.withValues(alpha: 0.72),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: FlixieColors.primary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 18, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TOP BILLED',
                      style: TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Sort cast',
                    initialValue: _sortByName,
                    onSelected: (value) => setState(() => _sortByName = value),
                    color: FlixieColors.surfaceElevated,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: false, child: Text('Billing order')),
                      PopupMenuItem(value: true, child: Text('Actor name')),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortByName ? 'Actor name' : 'Billing order',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: FlixieColors.medium, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyCastSearch()
                  : ListView.separated(
                      controller: scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(
                        height: 9,
                        child: Center(
                          child: Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      itemBuilder: (context, index) => _FullCastCard(
                        member: filtered[index],
                        parentContentId: widget.parentContentId,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullCastCard extends StatelessWidget {
  const _FullCastCard({
    required this.member,
    required this.parentContentId,
  });

  final MovieCastMember member;
  final int parentContentId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.pop(context);
          router.push(personDetailPath(
            member.id,
            source: DetailSource.personCredits,
            parentContentId: parentContentId,
            parentContentType: 'movie',
          ));
        },
        child: SizedBox(
          height: 94,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 76,
                  height: double.infinity,
                  child: member.profileImageUrl == null
                      ? const ColoredBox(
                          color: FlixieColors.surfaceElevated,
                          child: Icon(Icons.person_rounded,
                              color: FlixieColors.medium, size: 36),
                        )
                      : CachedNetworkImage(
                          imageUrl: member.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: FlixieColors.surfaceElevated,
                            child: Icon(Icons.person_rounded,
                                color: FlixieColors.medium, size: 36),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          height: 1.2,
                        ),
                      ),
                      if (member.character.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          member.character,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.medium, size: 26),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCastSearch extends StatelessWidget {
  const _EmptyCastSearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              color: FlixieColors.medium, size: 42),
          SizedBox(height: 10),
          Text('No cast members found',
              style: TextStyle(
                  color: FlixieColors.light, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}
