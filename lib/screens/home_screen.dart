import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/movie_short.dart';
import '../models/activity_list_item.dart';
import '../models/trending_groups.dart';
import '../models/watch_request.dart';
import '../models/watchlist_movie.dart';
import '../presentation/shared/friend_actions_controller.dart';
import '../presentation/shared/watchlist_actions_controller.dart';
import '../services/group_service.dart';
import '../providers/auth_provider.dart';
import '../services/movie_service.dart';
import '../services/recommendation_service.dart';
import '../services/request_service.dart';
import '../services/trending_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/skeleton.dart';
import '../widgets/flixie_page.dart';
import '../widgets/flixie_wordmark.dart';
import 'home/featured_card.dart';
import 'home/greeting_header.dart';
import 'home/section_header.dart';
import 'home/trending_groups_section.dart';
import 'profile/activity_tile.dart';

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
  List<ActivityListItem> _friendsActivity = [];
  TrendingGroupsResponse? _trendingGroups;
  bool _isTrendingGroupsLoading = true;
  String? _trendingGroupsError;
  RecommendationFromHighlyRatedResponse? _highlyRatedRecommendations;
  final Set<int> _watchlistUpdatesInFlight = <int>{};
  Set<int> _watchlistMovieIds = {};
  int _watchRequestsNeedingResponse = 0;
  int _watchRequestsScheduledToday = 0;
  int _watchRequestsUpcoming = 0;
  bool _watchRequestsLoading = true;
  bool _isLoading = true;
  String? _error;
  String? _loadedForUserId;
  AuthProvider? _authProvider;
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final WatchlistActionsController _watchlistActions =
      WatchlistActionsController.instance;
  final PageController _heroPageController = PageController();
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
      _watchRequestsLoading = true;
    });
    final auth = context.read<AuthProvider>();
    final movieService = context.read<MovieService>();
    // Re-fetch user + all cached data (notifications, friends, reviews, etc.)
    await auth.refreshUserData();
    final user = auth.dbUser;
    final region =
        (user?.country?['isoCode'] as String?)?.toUpperCase() ?? 'US';
    logger.d('[HomeScreen] loading, user=[200b${user?.id}, region=$region');

    try {
      final results = await Future.wait([
        TrendingService.getTrendingMovies(),
        movieService.getNowPlayingMovies(region: region),
        if (user != null)
          _friendActions.getFriendsActivityLists(user.id)
        else
          Future.value([]),
        if (user != null)
          RecommendationService.getRecommendationsFromHighlyRated(
                  userId: user.id)
              .catchError((_) => null)
        else
          Future.value(null),
        if (user != null)
          RecommendationService.getUserRecommendations(user.id)
              .catchError((_) => <MovieShort>[])
        else
          Future.value(<MovieShort>[]),
        if (user != null)
          _watchlistActions
              .getUserWatchlist(user.id)
              .catchError((_) => <WatchlistMovie>[])
        else
          Future.value(<WatchlistMovie>[]),
        if (user != null)
          RequestService.getWatchRequests(user.id)
              .catchError((_) => <WatchRequest>[])
        else
          Future.value(<WatchRequest>[]),
      ]);
      if (mounted) {
        final watchRequests = results.length > 6
            ? results[6] as List<WatchRequest>
            : <WatchRequest>[];
        setState(() {
          _featuredMovies = results[0] as List<MovieShort>;
          _nowPlayingMovies = (results[1] as List<MovieShort>).take(8).toList();
          _friendsActivity =
              results.length > 2 ? results[2] as List<ActivityListItem> : [];
          _highlyRatedRecommendations = results.length > 3
              ? results[3] as RecommendationFromHighlyRatedResponse?
              : null;
          final fallbackForYou = results.length > 4
              ? results[4] as List<MovieShort>
              : <MovieShort>[];
          _forYouMovies = (_highlyRatedRecommendations?.recommendations ?? [])
                  .isNotEmpty
              ? (_highlyRatedRecommendations!.recommendations).take(20).toList()
              : fallbackForYou.take(20).toList();
          final watchlist = results.length > 5
              ? results[5] as List<WatchlistMovie>
              : <WatchlistMovie>[];
          _watchlistMovieIds = watchlist.map((w) => w.movieId).toSet();
          if (user != null) {
            _watchRequestsNeedingResponse =
                _countWatchRequestsNeedingResponse(watchRequests, user.id);
            _watchRequestsScheduledToday =
                _countWatchRequestsScheduledToday(watchRequests);
            _watchRequestsUpcoming = _countUpcomingWatchRequests(watchRequests);
          } else {
            _watchRequestsNeedingResponse = 0;
            _watchRequestsScheduledToday = 0;
            _watchRequestsUpcoming = 0;
          }
          _watchRequestsLoading = false;
          _loadedForUserId = user?.id;
          _isLoading = false;
        });
      }
      if (mounted) {
        await _loadTrendingGroups();
      }
    } catch (e) {
      logger.e('[HomeScreen] load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _watchRequestsLoading = false;
          _error = 'Couldn\'t load content. Check your connection.';
        });
      }
    }
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

  int _countWatchRequestsScheduledToday(List<WatchRequest> requests) {
    return requests.where((request) {
      if (!_hasActiveAgreedSchedule(request)) return false;
      final scheduledFor = request.scheduledFor?.toLocal();
      if (scheduledFor == null) return false;
      return _isSameLocalDate(scheduledFor, DateTime.now());
    }).length;
  }

  int _countUpcomingWatchRequests(List<WatchRequest> requests) {
    final now = DateTime.now();
    return requests.where((request) {
      if (!_hasActiveAgreedSchedule(request)) return false;
      final scheduledFor = request.scheduledFor?.toLocal();
      return scheduledFor != null && scheduledFor.isAfter(now);
    }).length;
  }

  bool _hasActiveAgreedSchedule(WatchRequest request) {
    final watchedStatus = request.normalizedWatchedStatus;
    return request.isWatchRequest &&
        request.normalizedScheduleStatus == 'AGREED' &&
        request.scheduledFor != null &&
        watchedStatus != 'WATCHED' &&
        watchedStatus != 'NOT_WATCHED' &&
        !request.isTerminal;
  }

  bool _isSameLocalDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
      } else {
        final added = await _watchlistActions.addToWatchlist(user.id, movieId);
        currentWatchlist.removeWhere((item) => item.movieId == movieId);
        currentWatchlist.add(added);
        authProvider.markActivityChanged();
      }
      authProvider.updateUserList(movieWatchlist: currentWatchlist);
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

  Future<void> _playTrailer(BuildContext context, MovieShort movie) async {
    final movieId = movie.id;
    try {
      final movieService = context.read<MovieService>();
      final full = await movieService.getMovieById(movieId);
      final trailer = (full.videos ?? []).firstWhere(
        (v) => v.videoTypeName.toLowerCase().contains('trailer'),
        orElse: () => (full.videos ?? []).isNotEmpty
            ? full.videos!.first
            : throw Exception('no video'),
      );
      final uri = Uri.parse(trailer.youtubeUrl);
      if (context.mounted) {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) context.push('/movies/${movie.id}');
        }
      }
    } catch (_) {
      if (context.mounted) context.push('/movies/${movie.id}');
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
            icon: const Icon(
              Icons.search_outlined,
              color: FlixieColors.light,
            ),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
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
                            onSearch: () => context.push('/search'),
                            onWatchlist: () => context.go('/watchlist'),
                            onInvite: () => context.go('/social'),
                            onRequests: () => context.go('/watch-requests'),
                          ),
                        ),
                        _buildWatchPlansShortcut(context),
                        if (heroMovies.isNotEmpty) ...[
                          _buildHeroCarousel(context, heroMovies),
                          const SizedBox(height: 10),
                          _buildCarouselDots(heroMovies),
                          const SizedBox(height: 20),
                        ],
                        _buildBecauseYouRatedSection(context),
                        _buildJustOutSection(context),
                        _buildWatchlistSection(context),
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

  Widget _buildWatchPlansShortcut(BuildContext context) {
    final needsResponse = _watchRequestsNeedingResponse > 0;
    final hasToday = _watchRequestsScheduledToday > 0;
    final hasUpcoming = _watchRequestsUpcoming > 0;
    final accent = needsResponse
        ? FlixieColors.warning
        : hasToday
            ? FlixieColors.secondary
            : FlixieColors.primary;
    final subtitle = _watchPlansSubtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/watch-requests'),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.38)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasToday
                        ? Icons.event_available_outlined
                        : Icons.video_camera_back_outlined,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Watch plans',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (needsResponse) ...[
                            const SizedBox(width: 8),
                            _WatchPlanBadge(
                              label: '$_watchRequestsNeedingResponse',
                              color: FlixieColors.warning,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (!_watchRequestsLoading &&
                          (needsResponse || hasToday || hasUpcoming)) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (needsResponse)
                              _WatchPlanChip(
                                icon: Icons.reply_outlined,
                                label:
                                    '$_watchRequestsNeedingResponse to answer',
                                color: FlixieColors.warning,
                              ),
                            if (hasToday)
                              _WatchPlanChip(
                                icon: Icons.today_outlined,
                                label: '$_watchRequestsScheduledToday today',
                                color: FlixieColors.secondary,
                              ),
                            if (hasUpcoming)
                              _WatchPlanChip(
                                icon: Icons.schedule_outlined,
                                label: '$_watchRequestsUpcoming upcoming',
                                color: FlixieColors.primary,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: FlixieColors.light,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _watchPlansSubtitle {
    if (_watchRequestsLoading) return 'Checking your watch requests...';
    if (_watchRequestsNeedingResponse > 0) {
      return 'You have watch requests or schedule times waiting.';
    }
    if (_watchRequestsScheduledToday > 0) {
      final label = _watchRequestsScheduledToday == 1 ? 'watch' : 'watches';
      return 'You have $_watchRequestsScheduledToday $label scheduled today.';
    }
    if (_watchRequestsUpcoming > 0) {
      final label = _watchRequestsUpcoming == 1 ? 'watch' : 'watches';
      return '$_watchRequestsUpcoming upcoming $label with friends.';
    }
    return 'Schedule something to watch together.';
  }

  // ── Hero carousel ──────────────────────────────────────────────────────────

  Widget _buildHeroCarousel(BuildContext context, List<MovieShort> movies) {
    final count = movies.length.clamp(0, _maxHeroCarouselItems);
    return SizedBox(
      height: 438,
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroPageController,
            onPageChanged: (i) => setState(() => _heroPage = i),
            itemCount: count,
            itemBuilder: (context, index) =>
                _buildHeroCard(context, movies[index]),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      FlixieColors.background.withValues(alpha: 0.96),
                      FlixieColors.background.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
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

  Widget _buildHeroCard(BuildContext context, MovieShort movie) {
    final inWatchlist = _watchlistMovieIds.contains(movie.id);
    final isUpdating = _watchlistUpdatesInFlight.contains(movie.id);

    return GestureDetector(
      onTap: () => context.push('/movies/${movie.id}'),
      child: ColoredBox(
        color: FlixieColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (movie.poster != null)
                    CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w780${movie.poster}',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorWidget: (_, __, ___) => _heroFallback(),
                    )
                  else
                    _heroFallback(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.58, 0.82, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.16),
                          FlixieColors.background,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        _forYouMovies.isNotEmpty
                            ? 'Trending you might like'
                            : 'Trending now',
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  if ((movie.overview ?? '').isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      movie.overview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _playTrailer(context, movie),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text(
                            'Play Trailer',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlixieColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HeroIconButton(
                        tooltip: 'Movie details',
                        icon: Icons.info_outline_rounded,
                        onPressed: () => context.push('/movies/${movie.id}'),
                      ),
                      const SizedBox(width: 10),
                      _HeroIconButton(
                        tooltip:
                            inWatchlist ? 'Remove from watchlist' : 'Watchlist',
                        icon: inWatchlist
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        isBusy: isUpdating,
                        onPressed: () => _toggleHeroWatchlist(context, movie),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
                                PopupMenuItem(
                                  value: 'add_favourite',
                                  child: Text('Add to favourites'),
                                ),
                                PopupMenuItem(
                                  value: 'add_list',
                                  child: Text('Add to list'),
                                ),
                                PopupMenuItem(
                                  value: 'invite',
                                  child: Text('Invite friends to watch'),
                                ),
                                PopupMenuItem(
                                  value: 'share',
                                  child: Text('Share movie'),
                                ),
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
    final items = _friendsActivity.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Friend Activity',
          onSeeAll: () => context.go('/social'),
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
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    if (_watchlistUpdatesInFlight.contains(movieId)) return;
    final existing = auth.dbUser?.movieWatchlist ?? [];
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _watchlistUpdatesInFlight.add(movieId));
    try {
      if (currentlyInWatchlist) {
        await _watchlistActions.removeFromWatchlist(userId, movieId);
        auth.updateUserList(
          movieWatchlist: existing.where((w) => w.movieId != movieId).toList(),
        );
      } else {
        await _watchlistActions.addToWatchlist(userId, movieId);
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
            ListTile(
              leading:
                  const Icon(Icons.favorite_border, color: FlixieColors.danger),
              title: const Text('Add to favourites'),
              onTap: () => _handleNotYetImplementedAction(
                  sheetContext, 'Add to favourites'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_outlined,
                  color: FlixieColors.light),
              title: const Text('Add to list'),
              onTap: () =>
                  _handleNotYetImplementedAction(sheetContext, 'Add to list'),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined,
                  color: FlixieColors.primary),
              title: const Text('Invite friends to watch'),
              onTap: () => _handleNotYetImplementedAction(
                  sheetContext, 'Invite friends to watch'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined,
                  color: FlixieColors.secondary),
              title: const Text('Share movie'),
              onTap: () =>
                  _handleNotYetImplementedAction(sheetContext, 'Share movie'),
            ),
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
      case 'add_favourite':
        _showComingSoonToast(context, 'Add to favourites');
        break;
      case 'add_list':
        _showComingSoonToast(context, 'Add to list');
        break;
      case 'invite':
        _showComingSoonToast(context, 'Invite friends to watch');
        break;
      case 'share':
        _showComingSoonToast(context, 'Share movie');
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

  void _handleNotYetImplementedAction(BuildContext context, String action) {
    Navigator.of(context).pop();
    _showComingSoonToast(context, action);
  }

  void _showComingSoonToast(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action coming soon')),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isBusy = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isBusy;

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
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: isBusy ? FlixieColors.medium : Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchPlanBadge extends StatelessWidget {
  const _WatchPlanBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WatchPlanChip extends StatelessWidget {
  const _WatchPlanChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
