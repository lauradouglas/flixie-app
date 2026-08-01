import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flixie_app/models/trending_groups.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/home/presentation/widgets/featured_card.dart';
import 'package:flixie_app/features/home/presentation/widgets/greeting_header.dart';
import 'package:flixie_app/features/home/presentation/widgets/section_header.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_groups_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Keep hero carousel concise so primary CTA and dots remain visible above fold.
  static const int _maxHeroCarouselItems = 6;
  static const double _defaultQuickRating = 5;
  static const int _recentTheatreDays = 45;

  List<MovieShort> _featuredMovies = [];
  List<MovieShort> _nowPlayingMovies = [];
  List<MovieShort> _forYouMovies = [];
  List<ContinueWatchingShow> _continueWatchingShows = [];
  List<ActivityListItem> _friendsActivity = [];
  final Map<int, List<FriendMediaInteraction>> _heroFriendInteractions = {};
  bool _showMoreFriendActivity = false;
  TrendingGroupsResponse? _trendingGroups;
  bool _isTrendingGroupsLoading = true;
  String? _trendingGroupsError;
  final Set<int> _watchlistUpdatesInFlight = <int>{};
  Set<int> _watchlistMovieIds = {};
  int _watchRequestsNeedingResponse = 0;
  bool _isLoading = true;
  String? _error;
  String? _loadedForUserId;
  AuthProvider? _authProvider;
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final WatchlistActionsController _watchlistActions =
      WatchlistActionsController.instance;
  final PageController _heroPageController =
      PageController(viewportFraction: 0.84);
  int _heroPage = 0;

  List<MovieShort> get _heroMovies {
    if (_forYouMovies.isEmpty) return _featuredMovies;
    final forYouIds = _forYouMovies.map((movie) => movie.id).toSet();
    final matchingTrending =
        _featuredMovies.where((movie) => forYouIds.contains(movie.id));
    final remainingTrending =
        _featuredMovies.where((movie) => !forYouIds.contains(movie.id));
    return [...matchingTrending, ...remainingTrending];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider ??= context.read<AuthProvider>();
  }

  @override
  void initState() {
    super.initState();
    // Listen for dbUser becoming available after auth resolves
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider?.addListener(_onAuthChanged);
      _loadAll();
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _heroPageController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final userId = _authProvider?.dbUser?.id;
    if (userId != null && userId != _loadedForUserId) {
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isTrendingGroupsLoading = true;
      _trendingGroupsError = null;
    });
    final auth = context.read<AuthProvider>();
    final movieService = context.read<MovieService>();
    final user = auth.dbUser;
    final region =
        (user?.country?['isoCode'] as String?)?.toUpperCase() ?? 'US';
    logger.d('[HomeScreen] loading, user=[200b${user?.id}, region=$region');

    // Refresh the profile without holding up above-the-fold home content.
    unawaited(auth.refreshUserData());
    _loadedForUserId = user?.id;

    // Secondary sections manage their own loading/error states and should not
    // keep the whole page behind a skeleton.
    unawaited(_loadSecondaryContent(user));
    unawaited(_loadTrendingGroups());

    try {
      final results = await Future.wait([
        TrendingService.getTrendingMovies(),
        movieService.getNowPlayingMovies(region: region),
      ]);
      if (context.mounted) {
        setState(() {
          _featuredMovies = results[0];
          _nowPlayingMovies = results[1].take(8).toList();
          _isLoading = false;
        });
        if (user != null) {
          unawaited(_loadHeroFriendInteractions(results[0], user.id));
        }
      }
    } catch (e) {
      logger.e('[HomeScreen] load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Couldn\'t load content. Check your connection.';
        });
      }
    }
  }

  Future<void> _loadHeroFriendInteractions(
    List<MovieShort> movies,
    String userId,
  ) async {
    final results = await Future.wait(
      movies.take(_maxHeroCarouselItems).map((movie) async {
        try {
          final interactions = await FriendService.getFriendsMovieInteractions(
            userId,
            movie.id,
          );
          return MapEntry(movie.id, interactions);
        } catch (error) {
          logger.w(
            '[HomeScreen] friend interactions unavailable for ${movie.id}: $error',
          );
          return MapEntry(movie.id, <FriendMediaInteraction>[]);
        }
      }),
    );
    if (!mounted || _loadedForUserId != userId) return;
    setState(() {
      _heroFriendInteractions
        ..clear()
        ..addEntries(results);
    });
  }

  Future<void> _loadSecondaryContent(models.User? user) async {
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _friendsActivity = [];
        _forYouMovies = [];
        _continueWatchingShows = [];
        _watchlistMovieIds = {};
        _watchRequestsNeedingResponse = 0;
      });
      return;
    }

    final results = await Future.wait([
      _friendActions
          .getFriendsActivityLists(user.id)
          .catchError((_) => <ActivityListItem>[]),
      RecommendationService.getRecommendationsFromHighlyRated(userId: user.id)
          .catchError((_) => null),
      RecommendationService.getUserRecommendations(user.id)
          .catchError((_) => <MovieShort>[]),
      _watchlistActions
          .getUserWatchlist(user.id)
          .catchError((_) => <WatchlistMovie>[]),
      RequestService.getWatchRequests(user.id)
          .catchError((_) => <WatchRequest>[]),
      ShowService.getContinueWatching(user.id)
          .catchError((_) => <ContinueWatchingShow>[]),
    ]);
    if (!mounted || _loadedForUserId != user.id) return;

    final highlyRated = results[1] as RecommendationFromHighlyRatedResponse?;
    final fallbackForYou = results[2] as List<MovieShort>;
    final watchRequests = results[4] as List<WatchRequest>;
    setState(() {
      _friendsActivity = results[0] as List<ActivityListItem>;
      _forYouMovies = (highlyRated?.recommendations ?? []).isNotEmpty
          ? highlyRated!.recommendations.take(20).toList()
          : fallbackForYou.take(20).toList();
      _watchlistMovieIds = (results[3] as List<WatchlistMovie>)
          .map((item) => item.movieId)
          .toSet();
      _watchRequestsNeedingResponse =
          _countWatchRequestsNeedingResponse(watchRequests, user.id);
      _continueWatchingShows = results[5] as List<ContinueWatchingShow>;
    });
  }

  int _countWatchRequestsNeedingResponse(
    List<WatchRequest> requests,
    String userId,
  ) {
    return requests.where((request) {
      if (!request.isWatchRequest) return false;
      if (request.isPending && request.requesterId != userId) return true;
      final proposal = request.latestPendingProposal;
      if (request.normalizedScheduleStatus == 'PROPOSED' &&
          proposal != null &&
          proposal.proposerId != userId) {
        return true;
      }
      return request.canConfirmWatchedFor(userId);
    }).length;
  }

  Future<void> _loadTrendingGroups() async {
    if (!mounted) return;
    final user = context.read<AuthProvider>().dbUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _trendingGroups = null;
          _trendingGroupsError = null;
          _isTrendingGroupsLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isTrendingGroupsLoading = true;
        _trendingGroupsError = null;
      });
    }

    try {
      final response = await GroupService.getTrendingGroups();
      if (mounted) {
        setState(() {
          _trendingGroups = response;
          _isTrendingGroupsLoading = false;
        });
      }
    } catch (e) {
      logger.e('[HomeScreen] trending groups load error: $e');
      if (mounted) {
        setState(() {
          _trendingGroupsError = 'Couldn’t load group trends';
          _isTrendingGroupsLoading = false;
        });
      }
    }
  }

  Future<void> _toggleHeroWatchlist(
      BuildContext context, MovieShort movie) async {
    final authProvider = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final user = authProvider.dbUser;
    if (user == null) {
      context.push('/movies/${movie.id}');
      return;
    }
    final movieId = movie.id;
    if (_watchlistUpdatesInFlight.contains(movieId)) return;
    final inWatchlist = _watchlistMovieIds.contains(movieId);
    setState(() {
      _watchlistUpdatesInFlight.add(movieId);
      if (inWatchlist) {
        _watchlistMovieIds.remove(movieId);
      } else {
        _watchlistMovieIds.add(movieId);
      }
    });
    try {
      final currentWatchlist =
          List<WatchlistMovie>.from(user.movieWatchlist ?? []);
      if (inWatchlist) {
        await _watchlistActions.removeFromWatchlist(user.id, movieId);
        await analytics.watchlistItemRemoved(source: 'home');
        await analytics.movieRemovedFromWatchlist();
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
      } else {
        final added = await _watchlistActions.addToWatchlist(user.id, movieId);
        await analytics.watchlistItemAdded(source: 'home');
        await analytics.movieAddedToWatchlist();
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
        currentWatchlist.add(added);
        authProvider.markActivityChanged();
      }
      authProvider.updateUserList(movieWatchlist: currentWatchlist);
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                inWatchlist
                    ? '${movie.name} removed from your watchlist'
                    : '${movie.name} added to your watchlist',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor:
                  inWatchlist ? FlixieColors.surface : FlixieColors.success,
            ),
          );
      }
    } catch (e) {
      logger.e('[HomeScreen] watchlist toggle error: $e');
      if (mounted) {
        setState(() {
          if (inWatchlist) {
            _watchlistMovieIds.add(movieId);
          } else {
            _watchlistMovieIds.remove(movieId);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _watchlistUpdatesInFlight.remove(movieId));
    }
  }

  Future<void> _openHeroTrailer(
    BuildContext context,
    MovieShort movie,
  ) async {
    final rawUrl = movie.trailer?.key;
    if (rawUrl == null || rawUrl.isEmpty) return;
    final watchUrl = rawUrl.replaceFirst(
      'youtube.com/embed/',
      'youtube.com/watch?v=',
    );
    final uri = Uri.tryParse(watchUrl);
    var opened = false;
    try {
      opened = uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      logger.w('[HomeScreen] trailer launch failed for ${movie.id}: $error');
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open this trailer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<AuthProvider>().unreadNotificationCount;
    final user = context.watch<AuthProvider>().dbUser;
    final greetingName = (user?.firstName?.trim().isNotEmpty ?? false)
        ? user!.firstName!.trim()
        : user?.username;
    final heroMovies = _heroMovies;

    return FlixiePageScaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        foregroundColor: FlixieColors.light,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: FlixieColors.light),
        actionsIconTheme: const IconThemeData(color: FlixieColors.light),
        title: const FlixieWordmark(),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label:
                  unreadCount < 100 ? Text('$unreadCount') : const Text('99+'),
              backgroundColor: FlixieColors.tertiary,
              textColor: Colors.black,
              child: const Icon(
                Icons.notifications_outlined,
                color: FlixieColors.light,
              ),
            ),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await context.push('/notifications');
              // Refresh the badge count once the user returns from the screen
              if (mounted) {
                auth.refreshNotificationCount();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const HomeScreenSkeleton()
          : _error != null
              ? ErrorRetryWidget(
                  message: _error!,
                  onRetry: _loadAll,
                )
              : RefreshIndicator(
                  color: FlixieColors.primary,
                  backgroundColor: FlixieColors.background,
                  onRefresh: _loadAll,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GreetingHeader(
                            name: greetingName,
                            avatar: user?.avatar,
                            profileBadges: user?.profileBadges ?? const [],
                            requestCount: _watchRequestsNeedingResponse,
                            onSearch: () => context.push('/search'),
                            onWatchlist: () => context.go('/watchlist'),
                            onInvite: () => context.go('/social'),
                            onRequests: () => context.push('/watch-requests'),
                          ),
                        ),
                        if (heroMovies.isNotEmpty) ...[
                          HomeSectionHeader(
                            title: 'Trending now',
                            onSeeAll: () => context.push('/search'),
                          ),
                          const SizedBox(height: 4),
                          _buildHeroCarousel(context, heroMovies),
                          const SizedBox(height: 10),
                          _buildCarouselDots(heroMovies),
                          const SizedBox(height: 20),
                        ],
                        _buildBecauseYouRatedSection(context),
                        _buildJustOutSection(context),
                        _buildWatchlistSection(context),
                        _buildContinueWatchingSection(context),
                        _buildFriendActivitySection(context),
                        TrendingGroupsSection(
                          isLoading: _isTrendingGroupsLoading,
                          response: _trendingGroups,
                          errorMessage: _trendingGroupsError,
                          onRetry: _loadTrendingGroups,
                          onSeeAll: () => context.go('/social'),
                          onExploreGroups: () => context.go('/social'),
                          onOpenGroup: (groupId) =>
                              context.push('/groups/$groupId'),
                          onOpenMovie: (movieId) =>
                              context.push('/movies/$movieId'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildContinueWatchingSection(BuildContext context) {
    if (_continueWatchingShows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(title: 'Continue Watching'),
        const SizedBox(height: 12),
        SizedBox(
          height: 322,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _continueWatchingShows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final show = _continueWatchingShows[index];
              return _ContinueWatchingCard(
                show: show,
                onTap: () => context.push('/shows/${show.showId}'),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Hero carousel ──────────────────────────────────────────────────────────

  Widget _buildHeroCarousel(BuildContext context, List<MovieShort> movies) {
    final count = movies.length.clamp(0, _maxHeroCarouselItems);
    return SizedBox(
      height: 560,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: PageView.builder(
              controller: _heroPageController,
              padEnds: false,
              onPageChanged: (i) => setState(() => _heroPage = i),
              itemCount: count,
              itemBuilder: (context, index) {
                final posterCard =
                    _buildInactiveHeroCard(context, movies[index]);
                final detailCard = _buildHeroCard(context, movies[index]);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedBuilder(
                    animation: _heroPageController,
                    builder: (context, _) {
                      final page = _heroPageController.hasClients
                          ? (_heroPageController.page ?? _heroPage.toDouble())
                          : _heroPage.toDouble();
                      final detailOpacity =
                          (1 - (page - index).abs()).clamp(0.0, 1.0);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          posterCard,
                          IgnorePointer(
                            ignoring: detailOpacity < 0.98,
                            child: Opacity(
                              opacity: detailOpacity,
                              child: detailCard,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselDots(List<MovieShort> movies) {
    final count = movies.length.clamp(0, _maxHeroCarouselItems);
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _heroPage ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == _heroPage
                ? FlixieColors.primary
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    MovieShort movie,
  ) {
    final inWatchlist = _watchlistMovieIds.contains(movie.id);
    final isUpdating = _watchlistUpdatesInFlight.contains(movie.id);
    final interactions = _heroFriendInteractions[movie.id] ?? const [];
    final watchlistedBy =
        interactions.where((interaction) => interaction.onWatchlist).toList();
    final favouritedBy =
        interactions.where((interaction) => interaction.favourited).toList();
    final posterHeight = movie.name.length <= 20 ? 375.0 : 350.0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: FlixieColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () => context.push('/movies/${movie.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: posterHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (movie.poster != null)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w780${movie.poster}',
                            fit: BoxFit.cover,
                            color: Colors.black.withValues(alpha: 0.38),
                            colorBlendMode: BlendMode.darken,
                            errorWidget: (_, __, ___) => _heroFallback(),
                          ),
                        ),
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.62,
                            heightFactor: 1,
                            child: ClipRect(
                              child: CachedNetworkImage(
                                imageUrl:
                                    'https://image.tmdb.org/t/p/w780${movie.poster}',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorWidget: (_, __, ___) => _heroFallback(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    _heroFallback(),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                ),
                              ),
                              if ((movie.releaseDate ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatHeroDate(movie.releaseDate!),
                                  style: const TextStyle(
                                    color: FlixieColors.medium,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _HeroCompactIconButton(
                          tooltip: inWatchlist
                              ? 'Remove from watchlist'
                              : 'Watchlist',
                          icon: inWatchlist
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          foregroundColor: FlixieColors.warning,
                          isBusy: isUpdating,
                          onPressed: () => _toggleHeroWatchlist(context, movie),
                        ),
                      ],
                    ),
                    if ((movie.overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        movie.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        if ((movie.voteAverage ?? 0) > 0) ...[
                          const Icon(Icons.star_rounded,
                              color: FlixieColors.warning, size: 19),
                          const SizedBox(width: 4),
                          Text(
                            movie.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: FlixieColors.warning,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if ((movie.trailer?.key ?? '').isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 22,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: () => _openHeroTrailer(context, movie),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Trailer'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: Colors.redAccent.withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        _HeroCompactIconButton(
                          tooltip: 'Details',
                          icon: Icons.info_outline_rounded,
                          foregroundColor: FlixieColors.light,
                          onPressed: () => context.push('/movies/${movie.id}'),
                        ),
                      ],
                    ),
                    if (watchlistedBy.isNotEmpty ||
                        favouritedBy.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          if (watchlistedBy.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.bookmark_rounded,
                                    color: FlixieColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  _FriendInteractionAvatarStack(
                                    interactions: watchlistedBy,
                                  ),
                                ],
                              ),
                            )
                          else
                            const Spacer(flex: 2),
                          if (watchlistedBy.isNotEmpty &&
                              favouritedBy.isNotEmpty) ...[
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (favouritedBy.isNotEmpty) ...[
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: _FriendInteractionAvatarStack(
                                        interactions: favouritedBy,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveHeroCard(BuildContext context, MovieShort movie) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: FlixieColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () => context.push('/movies/${movie.id}'),
        child: movie.poster != null
            ? CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w780${movie.poster}',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorWidget: (_, __, ___) => _heroFallback(),
              )
            : _heroFallback(),
      ),
    );
  }

  Widget _heroFallback() {
    return Container(
      color: FlixieColors.tabBarBackgroundFocused,
      child: const Icon(
        Icons.movie_outlined,
        color: FlixieColors.medium,
        size: 48,
      ),
    );
  }

  Widget _buildJustOutSection(BuildContext context) {
    final items = _nowPlayingMovies.take(10).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Just Out',
          onSeeAll: () => context.push('/search'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = items[index];
              return FeaturedCard(
                movie: movie,
                showNewBadge: _isRecentlyAddedToTheatres(movie),
                onTap: () => context.push('/movies/${movie.id}'),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  bool _isRecentlyAddedToTheatres(MovieShort movie) {
    final raw = movie.releaseDate;
    if (raw == null || raw.isEmpty) return false;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return false;
    final release = DateTime(parsed.year, parsed.month, parsed.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceRelease = today.difference(release).inDays;

    return daysSinceRelease >= 0 && daysSinceRelease <= _recentTheatreDays;
  }

  Widget _buildWatchlistSection(BuildContext context) {
    final user = context.read<AuthProvider>().dbUser;
    final watchlist = user?.movieWatchlist
            ?.where((w) => w.removed != true)
            .take(10)
            .toList() ??
        [];
    if (watchlist.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'On Your Watchlist',
          onSeeAll: () => context.go('/watchlist'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: watchlist.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = watchlist[index];
              final isUpdating =
                  _watchlistUpdatesInFlight.contains(item.movieId);
              final posterUrl = item.movie?.posterPath != null
                  ? 'https://image.tmdb.org/t/p/w342${item.movie!.posterPath}'
                  : null;
              return GestureDetector(
                onTap: () => context.push('/movies/${item.movieId}'),
                onLongPress: () => _showQuickMovieActions(
                  context,
                  movieId: item.movieId,
                  movieTitle: item.movie?.title ?? 'Movie',
                  isInWatchlist: true,
                ),
                child: SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 110,
                              height: 148,
                              child: posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: FlixieColors
                                            .tabBarBackgroundFocused,
                                        child: const Icon(Icons.movie_outlined,
                                            color: FlixieColors.medium),
                                      ),
                                    )
                                  : Container(
                                      color:
                                          FlixieColors.tabBarBackgroundFocused,
                                      child: const Icon(Icons.movie_outlined,
                                          color: FlixieColors.medium),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: GestureDetector(
                              onTap: isUpdating
                                  ? null
                                  : () => _toggleWatchlistState(
                                        context,
                                        movieId: item.movieId,
                                        movieTitle:
                                            item.movie?.title ?? 'Movie',
                                        posterPath: item.movie?.posterPath,
                                        currentlyInWatchlist: true,
                                      ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  Icons.bookmark,
                                  color: isUpdating
                                      ? FlixieColors.medium
                                      : FlixieColors.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: PopupMenuButton<String>(
                              tooltip: 'Quick actions',
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: FlixieColors.light, size: 20),
                              color: FlixieColors.tabBarBackgroundFocused,
                              onSelected: (value) {
                                _handleQuickActionSelection(
                                  context,
                                  action: value,
                                  movieId: item.movieId,
                                  movieTitle: item.movie?.title ?? 'Movie',
                                  isInWatchlist: true,
                                );
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'mark_watched',
                                  child: Text('Mark as watched'),
                                ),
                                PopupMenuItem(
                                  value: 'remove_watchlist',
                                  child: Text('Remove from watchlist'),
                                ),
                                // TODO(release): Restore favourite, list,
                                // invite and share quick actions when their
                                // home-screen flows are implemented.
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.movie?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBecauseYouRatedSection(BuildContext context) {
    if (_forYouMovies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Just for you',
          onSeeAll: () => context.push('/search'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _forYouMovies.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => FeaturedCard(
              movie: _forYouMovies[index],
              onTap: () => context.push('/movies/${_forYouMovies[index].id}'),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFriendActivitySection(BuildContext context) {
    if (_friendsActivity.isEmpty) return const SizedBox.shrink();
    final previewCount = _showMoreFriendActivity ? 8 : 3;
    final items = _friendsActivity.take(previewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Friend Activity',
          onSeeAll: () => context.push('/friends-activity'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final item in items) ...[
                ActivityTile(item: item, compact: true),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        if (_friendsActivity.length > 3) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (!_showMoreFriendActivity)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showMoreFriendActivity = true),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Show more'),
                    ),
                  ),
                if (!_showMoreFriendActivity) const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => context.push('/friends-activity'),
                    icon: const Icon(Icons.people_outline_rounded),
                    label: const Text('Show all'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _toggleWatchlistState(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
    required String? posterPath,
    required bool currentlyInWatchlist,
  }) async {
    final auth = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    if (_watchlistUpdatesInFlight.contains(movieId)) return;
    final existing = auth.dbUser?.movieWatchlist ?? [];
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _watchlistUpdatesInFlight.add(movieId));
    try {
      if (currentlyInWatchlist) {
        await _watchlistActions.removeFromWatchlist(userId, movieId);
        await analytics.watchlistItemRemoved(source: 'home');
        await analytics.movieRemovedFromWatchlist();
        auth.updateUserList(
          movieWatchlist: existing.where((w) => w.movieId != movieId).toList(),
        );
      } else {
        await _watchlistActions.addToWatchlist(userId, movieId);
        await analytics.watchlistItemAdded(source: 'home');
        await analytics.movieAddedToWatchlist();
        final now = DateTime.now().toIso8601String();
        auth.updateUserList(
          movieWatchlist: [
            WatchlistMovie(
              id: 'local-$movieId-$now',
              userId: userId,
              movieId: movieId,
              createdAt: now,
              movie: WatchlistMovieDetails(
                id: movieId,
                title: movieTitle,
                posterPath: posterPath,
              ),
            ),
            ...existing.where((w) => w.movieId != movieId),
          ],
        );
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(currentlyInWatchlist
                ? '$movieTitle removed from watchlist'
                : '$movieTitle added to watchlist'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      logger.w('[HomeScreen] watchlist toggle failed: $e');
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not update watchlist right now')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _watchlistUpdatesInFlight.remove(movieId));
      }
    }
  }

  void _showQuickMovieActions(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
    required bool isInWatchlist,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: FlixieColors.success),
              title: const Text('Mark as watched'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openQuickMarkWatchedSheet(
                  context,
                  movieId: movieId,
                  movieTitle: movieTitle,
                  isInWatchlist: isInWatchlist,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined,
                  color: FlixieColors.warning),
              title: const Text('Remove from watchlist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _toggleWatchlistState(
                  context,
                  movieId: movieId,
                  movieTitle: movieTitle,
                  posterPath: null,
                  currentlyInWatchlist: true,
                );
              },
            ),
            // TODO(release): Restore favourite, list, invite and share quick
            // actions when their home-screen flows are implemented.
          ],
        ),
      ),
    );
  }

  void _handleQuickActionSelection(
    BuildContext context, {
    required String action,
    required int movieId,
    required String movieTitle,
    required bool isInWatchlist,
  }) {
    switch (action) {
      case 'mark_watched':
        _openQuickMarkWatchedSheet(
          context,
          movieId: movieId,
          movieTitle: movieTitle,
          isInWatchlist: isInWatchlist,
        );
        break;
      case 'remove_watchlist':
        _toggleWatchlistState(
          context,
          movieId: movieId,
          movieTitle: movieTitle,
          posterPath: null,
          currentlyInWatchlist: true,
        );
        break;
    }
  }

  Future<void> _openQuickMarkWatchedSheet(
    BuildContext context, {
    required int movieId,
    required String movieTitle,
    required bool isInWatchlist,
  }) async {
    final auth = context.read<AuthProvider>();
    final analytics = context.read<AnalyticsController>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    double rating = _defaultQuickRating;
    bool includeRating = true;
    bool rewatch = false;
    final notesController = TextEditingController();
    final watchedAt = DateTime.now();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> commitWatchedEntry() async {
      try {
        await _watchlistActions.addToWatched(userId, movieId);
        if (isInWatchlist) {
          await _watchlistActions.removeFromWatchlist(userId, movieId);
          await analytics.watchlistItemRemoved(source: 'home');
          await analytics.movieRemovedFromWatchlist();
          final currentWatchlist = auth.dbUser?.movieWatchlist ?? [];
          auth.updateUserList(
            movieWatchlist: currentWatchlist
                .where((entry) => entry.movieId != movieId)
                .toList(),
          );
        }
        if (mounted) {
          navigator.maybePop();
          final ratingLabel =
              includeRating ? ' • ${rating.toStringAsFixed(0)}/10' : '';
          final noteLabel =
              notesController.text.trim().isNotEmpty ? ' • note saved' : '';
          final rewatchLabel = rewatch ? ' • rewatch' : '';
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '$movieTitle marked watched$ratingLabel$noteLabel$rewatchLabel',
              ),
            ),
          );
        }
      } catch (e) {
        logger.w('[HomeScreen] mark watched failed: $e');
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
                content: Text('Could not mark this movie as watched')),
          );
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark watched · $movieTitle',
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: includeRating,
                title: const Text('Add rating'),
                subtitle: Text(
                  includeRating
                      ? '${rating.toStringAsFixed(0)}/10'
                      : 'Skip rating',
                ),
                onChanged: (value) =>
                    setSheetState(() => includeRating = value),
              ),
              if (includeRating)
                Slider(
                  value: rating,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: rating.toStringAsFixed(0),
                  onChanged: (value) => setSheetState(() => rating = value),
                ),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional review',
                  filled: true,
                  fillColor: FlixieColors.background.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: rewatch,
                title: const Text('Rewatch'),
                subtitle: Text(
                    'Watched on ${watchedAt.day}/${watchedAt.month}/${watchedAt.year}'),
                onChanged: (value) => setSheetState(() => rewatch = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() => includeRating = false);
                        commitWatchedEntry();
                      },
                      child: const Text('Mark without rating'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: commitWatchedEntry,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    notesController.dispose();
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({
    required this.show,
    required this.onTap,
  });

  final ContinueWatchingShow show;
  final VoidCallback onTap;

  static const double _cardWidth = 168;
  static const double _posterHeight = _cardWidth * 1.5;

  @override
  Widget build(BuildContext context) {
    final episode = show.lastWatchedEpisode;
    final episodeLabel = episode == null
        ? '${show.watchedEpisodes} episodes watched'
        : 'S${episode.seasonNumber} E${episode.episodeNumber} watched';
    final progress = (show.completionPercent / 100).clamp(0.0, 1.0);
    final posterUrl = show.posterPath == null
        ? null
        : 'https://image.tmdb.org/t/p/w342${show.posterPath}';

    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: _cardWidth,
                      height: _posterHeight,
                      child: posterUrl == null
                          ? _posterFallback()
                          : CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _posterFallback(),
                              errorWidget: (_, __, ___) => _posterFallback(),
                            ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.black54,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          FlixieColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                show.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                episodeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: FlixieColors.tabBarBackgroundFocused,
      alignment: Alignment.center,
      child: const Icon(
        Icons.tv_rounded,
        color: FlixieColors.medium,
        size: 38,
      ),
    );
  }
}

String _formatHeroDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _FriendInteractionAvatarStack extends StatelessWidget {
  const _FriendInteractionAvatarStack({required this.interactions});

  final List<FriendMediaInteraction> interactions;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 30.0;
    const avatarSpacing = 22.0;
    final visible = interactions.take(3).toList(growable: false);
    final overflow = interactions.length - visible.length;
    final itemCount = visible.length + (overflow > 0 ? 1 : 0);
    return SizedBox(
      width: avatarSize + ((itemCount - 1).clamp(0, 3) * avatarSpacing),
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * avatarSpacing,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: FlixieColors.primary,
                  shape: BoxShape.circle,
                ),
                child: ProfileAvatarView(
                  avatar: visible[index].avatar,
                  fallbackText: visible[index].username.isEmpty
                      ? '?'
                      : visible[index].username[0].toUpperCase(),
                  fallbackColor: FlixieColors.surfaceElevated,
                  size: 27,
                  profileBadges: visible[index].profileBadges,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * avatarSpacing,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlixieColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: FlixieColors.primary, width: 1.5),
                ),
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCompactIconButton extends StatelessWidget {
  const _HeroCompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isBusy = false,
    this.foregroundColor = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isBusy;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isBusy ? null : onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: isBusy
                ? _SpinningActionIcon(icon: icon, color: foregroundColor)
                : Icon(icon, color: foregroundColor, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SpinningActionIcon extends StatefulWidget {
  const _SpinningActionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_SpinningActionIcon> createState() => _SpinningActionIconState();
}

class _SpinningActionIconState extends State<_SpinningActionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, color: widget.color, size: 22),
    );
  }
}
