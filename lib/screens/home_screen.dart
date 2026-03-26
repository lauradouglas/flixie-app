import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/movie_short.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  List<MovieShort> _featuredMovies = [];
  List<MovieShort> _nowPlayingMovies = [];
  bool _isLoading = true;
  String? _loadedForUserId;

  @override
  void initState() {
    super.initState();
    // Listen for dbUser becoming available after auth resolves
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().addListener(_onAuthChanged);
      _loadFeaturedMovies();
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId != null && userId != _loadedForUserId) {
      _loadFeaturedMovies();
    }
  }

  Future<void> _loadFeaturedMovies() async {
    final user = context.read<AuthProvider>().dbUser;
    final region = (user?.country?['isoCode'] as String?)?.toUpperCase() ?? 'US';
    logger.d('[HomeScreen] loading, user=${user?.id}, region=$region');

    try {
      final futures = await Future.wait([
        TrendingService.getTrendingMovies(),
        MovieService.getNowPlayingMovies(region: region),
      ]);
      if (mounted) {
        setState(() {
          _featuredMovies = futures[0];
          _nowPlayingMovies = futures[1];
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flixie'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Featured section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Featured', style: textTheme.headlineSmall),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _featuredMovies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _FeaturedCard(
                        movie: _featuredMovies[index],
                        onTap: () => context.push('/movies/${_featuredMovies[index].id}'),
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Popular section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('In Theatres Now', style: textTheme.headlineSmall),
            ),
            const SizedBox(height: 12),
            if (!_isLoading)
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
                    if (movie.releaseDate != null && movie.releaseDate!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        () {
                          final raw = movie.releaseDate!;
                          // Handle ISO format: "2026-03-15" or "2026-03-15T..."
                          final iso = DateTime.tryParse(raw);
                          if (iso != null) return iso.year.toString();
                          // Handle JS date string: "Sun Mar 15 2026"
                          final parts = raw.split(' ');
                          if (parts.length == 4) return '${parts[2]} ${parts[1]} ${parts[3]}';
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
                          imageUrl: 'https://image.tmdb.org/t/p/w92${movie.poster}',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.movie, color: FlixieColors.primary),
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
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (movie.releaseDate != null && movie.releaseDate!.length >= 4) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Released: ${movie.releaseDate!}',
                        style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
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
