import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/movie_short.dart';
import '../models/top_rated_movie.dart';
import '../models/activity_list_item.dart';
import '../services/friend_service.dart';
import 'profile/activity_tile.dart';
import '../providers/auth_provider.dart';
import '../services/movie_service.dart';
import '../services/trending_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<MovieShort> _featuredMovies = [];
  List<MovieShort> _nowPlayingMovies = [];
  List<TopRatedMovie> _topRatedThisWeek = [];
  List<ActivityListItem> _friendsActivity = [];
  bool _isLoading = true;
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
      ]);
      if (mounted) {
        setState(() {
          _featuredMovies = results[0] as List<MovieShort>;
          _nowPlayingMovies = results[1] as List<MovieShort>;
          _friendsActivity =
              results.length > 2 ? results[2] as List<ActivityListItem> : [];
          _topRatedThisWeek = results[3] as List<TopRatedMovie>;
          _loadedForUserId = user?.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.e('[HomeScreen] load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          ? const Center(
              child: CircularProgressIndicator(color: FlixieColors.primary))
          : RefreshIndicator(
              color: FlixieColors.primary,
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    if (_showGreeting)
                      _GreetingHeader(
                        name: context.read<AuthProvider>().dbUser?.username,
                        onDismiss: () => setState(() => _showGreeting = false),
                      ),
                    _SectionHeader(title: 'Featured'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _featuredMovies.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => _FeaturedCard(
                          movie: _featuredMovies[index],
                          onTap: () => context
                              .push('/movies/${_featuredMovies[index].id}'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Popular section
                    _SectionHeader(title: 'In Theatres Now'),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _nowPlayingMovies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final movie = _nowPlayingMovies[index];
                        return _ListCard(
                          movie: movie,
                          onTap: () => context.push('/movies/${movie.id}'),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Top Rated This Week section
                    _SectionHeader(title: 'Top Rated This Week'),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _topRatedThisWeek.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final movie = _topRatedThisWeek[index];
                            return _TopRatedCard(
                              movie: movie,
                              onTap: () => context.push('/movies/${movie.id}'),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Friends Activity section
                    _SectionHeader(title: 'Friends Activity'),
                    const SizedBox(height: 12),
                    if (_friendsActivity.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text('No recent activity from friends.',
                            style: textTheme.bodySmall
                                ?.copyWith(color: FlixieColors.medium)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _friendsActivity.length > 10
                            ? 10
                            : _friendsActivity.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            ActivityTile(item: _friendsActivity[i]),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.name, required this.onDismiss});

  final String? name;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final label = name != null
        ? '${_greeting()}, $name \u{1F44B}'
        : '${_greeting()} \u{1F44B}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: FlixieColors.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: FlixieColors.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child:
                  const Icon(Icons.close, size: 18, color: FlixieColors.medium),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              if (movie.poster != null)
                CachedNetworkImage(
                  imageUrl: 'https://image.tmdb.org/t/p/w342${movie.poster}',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: FlixieColors.primary.withValues(alpha: 0.3),
                    child: const Icon(Icons.movie_outlined, size: 36),
                  ),
                )
              else
                Container(
                  color: FlixieColors.primary.withValues(alpha: 0.3),
                  child: const Icon(Icons.movie_outlined, size: 36),
                ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              // Text content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      movie.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (movie.releaseDate != null &&
                        movie.releaseDate!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        () {
                          final raw = movie.releaseDate!;
                          // Handle ISO format: "2026-03-15" or "2026-03-15T..."
                          final iso = DateTime.tryParse(raw);
                          if (iso != null) return iso.year.toString();
                          // Handle JS date string: "Sun Mar 15 2026"
                          final parts = raw.split(' ');
                          if (parts.length == 4) {
                            return '${parts[2]} ${parts[1]} ${parts[3]}';
                          }
                          return raw;
                        }(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.movie, this.onTap});

  final MovieShort movie;
  final VoidCallback? onTap;

  Future<void> _searchInCinemas() async {
    final query = Uri.encodeComponent('${movie.name} in cinemas near me');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 60,
                  height: 90,
                  color: FlixieColors.primary.withValues(alpha: 0.3),
                  child: movie.poster != null
                      ? CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w92${movie.poster}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.movie,
                              color: FlixieColors.primary),
                        )
                      : const Icon(Icons.movie, color: FlixieColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              // Title + year
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (movie.releaseDate != null &&
                        movie.releaseDate!.length >= 4) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Released: ${movie.releaseDate!}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: FlixieColors.medium),
                      ),
                    ],
                  ],
                ),
              ),
              // Cinema search button
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Find in cinemas',
                color: FlixieColors.primary,
                onPressed: _searchInCinemas,
              ),
              const Icon(Icons.chevron_right, color: FlixieColors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopRatedCard extends StatelessWidget {
  const _TopRatedCard({required this.movie, this.onTap});

  final TopRatedMovie movie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              if (movie.posterPath != null)
                CachedNetworkImage(
                  imageUrl:
                      'https://image.tmdb.org/t/p/w342${movie.posterPath}',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: FlixieColors.primary.withValues(alpha: 0.3),
                    child: const Icon(Icons.movie_outlined, size: 36),
                  ),
                )
              else
                Container(
                  color: FlixieColors.primary.withValues(alpha: 0.3),
                  child: const Icon(Icons.movie_outlined, size: 36),
                ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              // Text content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: FlixieColors.tertiary),
                        const SizedBox(width: 3),
                        Text(
                          movie.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: FlixieColors.tertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${movie.ratingCount})',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: FlixieColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
