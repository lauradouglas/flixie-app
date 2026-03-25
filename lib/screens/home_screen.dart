import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trending_movie.dart';
import '../services/trending_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TrendingMovie> _featuredMovies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeaturedMovies();
  }

  Future<void> _loadFeaturedMovies() async {
    try {
      final movies = await TrendingService.getTrendingMovies();
      if (mounted) {
        setState(() {
          _featuredMovies = movies;
          _isLoading = false;
        });
      }
    } catch (e) {
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
              child: Text('Popular', style: textTheme.headlineSmall),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ListCard(index: index, onTap: () => context.push('/movies/${index + 10}')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.movie, this.onTap});

  final TrendingMovie movie;
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
                    if (movie.releaseDate != null && movie.releaseDate!.length >= 4) ...[
                      const SizedBox(height: 4),
                      Text(
                        movie.releaseDate!.substring(0, 4),
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
  const _ListCard({required this.index, this.onTap});

  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: FlixieColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.movie, color: FlixieColors.primary),
        ),
        title: Text('Movie Title ${index + 1}'),
        subtitle: Text('Genre • ${2020 + index}'),
        trailing: const Icon(
          Icons.chevron_right,
          color: FlixieColors.medium,
        ),
        onTap: onTap,
      ),
    );
  }
}
