import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie_short.dart';
import '../models/top_rated_movie.dart';
import '../models/activity_list_item.dart';
import '../services/friend_service.dart';
import '../providers/auth_provider.dart';
import '../services/movie_service.dart';
import '../services/recommendation_service.dart';
import '../services/trending_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/skeleton.dart';
import 'home/featured_card.dart';
import 'home/greeting_header.dart';
import 'home/section_header.dart';
import 'home/top_rated_card.dart';
import 'home/trending_friends_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<MovieShort> _featuredMovies = [];
  List<MovieShort> _nowPlayingMovies = [];
  List<MovieShort> _forYouMovies = [];
  List<TopRatedMovie> _topRatedThisWeek = [];
  List<ActivityListItem> _friendsActivity = [];
  bool _isLoading = true;
  String? _error;
  bool _showGreeting = true;
  String? _loadedForUserId;
  Timer? _greetingTimer;
  AuthProvider? _authProvider;
  final PageController _heroPageController = PageController();
  int _heroPage = 0;

  static final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();

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
      _greetingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _showGreeting) setState(() => _showGreeting = false);
      });
      // Subscribe to route events to dismiss greeting on navigate-away
      final route = ModalRoute.of(context);
      if (route != null) _routeObserver.subscribe(this, route);
    });
  }

  @override
  void didPushNext() {
    // User navigated away — dismiss greeting permanently
    if (_showGreeting) setState(() => _showGreeting = false);
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _routeObserver.unsubscribe(this);
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
    });
    final auth = context.read<AuthProvider>();
    // Re-fetch user + all cached data (notifications, friends, reviews, etc.)
    await auth.refreshUserData();
    final user = auth.dbUser;
    final region =
        (user?.country?['isoCode'] as String?)?.toUpperCase() ?? 'US';
    logger.d('[HomeScreen] loading, user=[200b${user?.id}, region=$region');

    try {
      final movieService = context.read<MovieService>();
      final results = await Future.wait([
        TrendingService.getTrendingMovies(),
        movieService.getNowPlayingMovies(region: region),
        if (user != null)
          FriendService.getFriendsActivityLists(user.id)
        else
          Future.value([]),
        movieService.getTopRatedThisWeek(),
        if (user != null)
          RecommendationService.getUserRecommendations(user.id)
              .catchError((_) => <MovieShort>[])
        else
          Future.value(<MovieShort>[]),
      ]);
      if (mounted) {
        setState(() {
          _featuredMovies = results[0] as List<MovieShort>;
          _nowPlayingMovies = (results[1] as List<MovieShort>).take(8).toList();
          _friendsActivity =
              results.length > 2 ? results[2] as List<ActivityListItem> : [];
          _topRatedThisWeek = results[3] as List<TopRatedMovie>;
          _forYouMovies = results.length > 4
              ? (results[4] as List<MovieShort>).take(20).toList()
              : [];
          _loadedForUserId = user?.id;
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<AuthProvider>().unreadNotificationCount;

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'fli',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'xie',
                style: TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
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
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              await context.push('/notifications');
              // Refresh the badge count once the user returns from the screen
              if (mounted) {
                context.read<AuthProvider>().refreshNotificationCount();
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting
                        if (_showGreeting)
                          GreetingHeader(
                            name: context
                                .read<AuthProvider>()
                                .dbUser
                                ?.username,
                            onDismiss: () =>
                                setState(() => _showGreeting = false),
                          ),
                        // Hero Carousel
                        if (_featuredMovies.isNotEmpty) ...[
                          _buildHeroCarousel(context),
                          const SizedBox(height: 10),
                          _buildCarouselDots(),
                          const SizedBox(height: 22),
                        ],
                        // Trending Now
                        HomeSectionHeader(
                          title: 'Trending Now',
                          onSeeAll: () => context.push('/search'),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: _featuredMovies.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => FeaturedCard(
                              movie: _featuredMovies[index],
                              onTap: () => context.push(
                                  '/movies/${_featuredMovies[index].id}'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // On Your Watchlist
                        _buildWatchlistSection(context),
                        // In Theatres Now
                        HomeSectionHeader(
                          title: 'In Theatres Now',
                          onSeeAll: () => context.push('/search'),
                        ),
                        const SizedBox(height: 12),
                        if (_nowPlayingMovies.isNotEmpty)
                          SizedBox(
                            height: 260,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _nowPlayingMovies.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) => FeaturedCard(
                                movie: _nowPlayingMovies[index],
                                onTap: () => context.push(
                                    '/movies/${_nowPlayingMovies[index].id}'),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Top Rated This Week
                        const HomeSectionHeader(
                            title: 'Top Rated This Week'),
                        const SizedBox(height: 12),
                        if (_topRatedThisWeek.isNotEmpty)
                          SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _topRatedThisWeek.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final movie = _topRatedThisWeek[index];
                                return TopRatedCard(
                                  movie: movie,
                                  onTap: () => context
                                      .push('/movies/${movie.id}'),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),
                        // Trending Among Friends
                        if (_friendsActivity.isNotEmpty)
                          TrendingAmongFriendsSection(
                              activity: _friendsActivity),
                        // For You
                        if (_forYouMovies.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          HomeSectionHeader(
                            title: 'For You',
                            onSeeAll: null,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _forYouMovies.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) => FeaturedCard(
                                movie: _forYouMovies[index],
                                onTap: () => context.push(
                                    '/movies/${_forYouMovies[index].id}'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  // ── Hero carousel ──────────────────────────────────────────────────────────

  Widget _buildHeroCarousel(BuildContext context) {
    final count = _featuredMovies.length.clamp(0, 6);
    return SizedBox(
      height: 400,
      child: PageView.builder(
        controller: _heroPageController,
        onPageChanged: (i) => setState(() => _heroPage = i),
        itemCount: count,
        itemBuilder: (context, index) =>
            _buildHeroCard(context, _featuredMovies[index]),
      ),
    );
  }

  Widget _buildCarouselDots() {
    final count = _featuredMovies.length.clamp(0, 6);
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
    final year =
        movie.releaseDate != null && movie.releaseDate!.length >= 4
            ? movie.releaseDate!.substring(0, 4)
            : '';
    final vote = movie.voteAverage != null && movie.voteAverage! > 0
        ? movie.voteAverage!.toStringAsFixed(1)
        : null;

    return GestureDetector(
      onTap: () => context.push('/movies/${movie.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background poster
            if (movie.poster != null)
              CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w780${movie.poster}',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: FlixieColors.tabBarBackgroundFocused,
                  child: const Icon(Icons.movie_outlined,
                      color: FlixieColors.medium, size: 48),
                ),
              )
            else
              Container(
                color: FlixieColors.tabBarBackgroundFocused,
                child: const Icon(Icons.movie_outlined,
                    color: FlixieColors.medium, size: 48),
              ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.38, 0.68, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
            // Rating badge – top right
            if (vote != null)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: FlixieColors.tertiary.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: FlixieColors.tertiary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        vote,
                        style: const TextStyle(
                            color: FlixieColors.tertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            // Bottom content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (year.isNotEmpty)
                    Text(
                      year,
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 12,
                          letterSpacing: 1.5),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    movie.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if ((movie.overview ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      movie.overview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 13,
                          height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/movies/${movie.id}'),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Play Trailer',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FlixieColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/movies/${movie.id}'),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('My List',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.55)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
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

  Widget _buildWatchlistSection(BuildContext context) {
    final user = context.read<AuthProvider>().dbUser;
    final watchlist =
        user?.movieWatchlist?.where((w) => w.removed != true).take(10).toList() ??
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
              final posterUrl = item.movie?.posterPath != null
                  ? 'https://image.tmdb.org/t/p/w342${item.movie!.posterPath}'
                  : null;
              return GestureDetector(
                onTap: () => context.push('/movies/${item.movieId}'),
                child: SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color:
                                        FlixieColors.tabBarBackgroundFocused,
                                    child: const Icon(Icons.movie_outlined,
                                        color: FlixieColors.medium),
                                  ),
                                )
                              : Container(
                                  color: FlixieColors.tabBarBackgroundFocused,
                                  child: const Icon(Icons.movie_outlined,
                                      color: FlixieColors.medium),
                                ),
                        ),
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
}
