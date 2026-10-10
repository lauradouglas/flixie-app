import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie.dart';

class FullScreenMoviePoster extends StatelessWidget {
  const FullScreenMoviePoster({super.key, required this.movie});

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
                      ? Center(
                          child: Icon(
                            Icons.movie_outlined,
                            color: context.colors.medium,
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
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: context.colors.medium,
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
