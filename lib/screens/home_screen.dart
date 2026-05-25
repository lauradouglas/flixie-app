import 'dart:async';

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
import 'home/list_card.dart';
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
    final textTheme = Theme.of(context).textTheme;
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
                            name: context.read<AuthProvider>().dbUser?.username,
                            onDismiss: () =>
                                setState(() => _showGreeting = false),
                          ),
                        if (_featuredMovies.isNotEmpty) ...[
                          _buildHeroFeature(context, _featuredMovies.first),
                          const SizedBox(height: 22),
                        ],
                        HomeSectionHeader(
                          title: 'Trending Now',
                          onSeeAll: () => context.push('/search'),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _featuredMovies.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => FeaturedCard(
                              movie: _featuredMovies[index],
                              onTap: () => context
                                  .push('/movies/${_featuredMovies[index].id}'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // For You section
                        if (_forYouMovies.isNotEmpty) ...[
                          HomeSectionHeader(
                            title: 'For You',
                            onSeeAll: null,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _forYouMovies.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) => FeaturedCard(
                                movie: _forYouMovies[index],
                                onTap: () => context
                                    .push('/movies/${_forYouMovies[index].id}'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Popular section
                        const HomeSectionHeader(title: 'In Cinemas'),
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
                          decoration: BoxDecoration(
                            color: FlixieColors.tabBarBackgroundFocused,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _nowPlayingMovies.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final movie = _nowPlayingMovies[index];
                              return HomeListCard(
                                movie: movie,
                                onTap: () => context.push('/movies/${movie.id}'),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Top Rated This Week section
                        const HomeSectionHeader(title: 'Top Rated This Week'),
                        const SizedBox(height: 12),
                        if (_topRatedThisWeek.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text('No top rated movies this week.',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: FlixieColors.medium)),
                          )
                        else
                          SizedBox(
                            height: 220,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _topRatedThisWeek.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final movie = _topRatedThisWeek[index];
                                return TopRatedCard(
                                  movie: movie,
                                  onTap: () =>
                                      context.push('/movies/${movie.id}'),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Trending Among Friends section
                        if (_friendsActivity.isNotEmpty)
                          TrendingAmongFriendsSection(
                              activity: _friendsActivity),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeroFeature(BuildContext context, MovieShort movie) {
    final releaseYear = movie.releaseDate != null && movie.releaseDate!.length >= 4
        ? movie.releaseDate!.substring(0, 4)
        : '';
    final vote = movie.voteAverage != null && movie.voteAverage! > 0
        ? movie.voteAverage!.toStringAsFixed(1)
        : 'N/A';

    return Container(
      height: 360,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (movie.poster != null)
            Image.network(
              'https://image.tmdb.org/t/p/w780${movie.poster}',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: FlixieColors.tabBarBackgroundFocused,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.movie_outlined,
                  color: FlixieColors.medium,
                  size: 46,
                ),
              ),
            )
          else
            Container(
              color: FlixieColors.tabBarBackgroundFocused,
              alignment: Alignment.center,
              child: const Icon(
                Icons.movie_outlined,
                color: FlixieColors.medium,
                size: 46,
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.86),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.5)),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (releaseYear.isNotEmpty)
                  Text(
                    releaseYear,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  movie.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                if ((movie.overview ?? '').isNotEmpty)
                  Text(
                    movie.overview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => context.push('/movies/${movie.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlixieColors.primary,
                    side: const BorderSide(color: FlixieColors.primary),
                    backgroundColor: Colors.black.withValues(alpha: 0.28),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text(
                    'View movie',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
