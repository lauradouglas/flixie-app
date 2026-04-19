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
      final results = await Future.wait([
        TrendingService.getTrendingMovies(),
        MovieService.getNowPlayingMovies(region: region),
        if (user != null)
          FriendService.getFriendsActivityLists(user.id)
        else
          Future.value([]),
        MovieService.getTopRatedThisWeek(),
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
        title: const Text('Flixie'),
        actions: [
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
                        HomeSectionHeader(
                          title: 'Featured',
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
                        const SizedBox(height: 24),
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
                                onTap: () => context.push(
                                    '/movies/${_forYouMovies[index].id}'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        // Popular section
                        const HomeSectionHeader(title: 'In Theatres Now'),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 24),

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
}
