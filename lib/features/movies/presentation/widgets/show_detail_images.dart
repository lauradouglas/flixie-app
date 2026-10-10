import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/movies/presentation/utils/show_image_url.dart';

class ShowPoster extends StatelessWidget {
  const ShowPoster({super.key, this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final url = showImageUrl(path, 'w500');
    if (url == null) return const _ImageFallback(icon: Icons.tv_rounded);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const _ImageFallback(icon: Icons.tv_rounded),
      errorWidget: (_, __, ___) => const _ImageFallback(icon: Icons.tv_rounded),
    );
  }
}

class FullScreenShowPoster extends StatelessWidget {
  const FullScreenShowPoster({super.key, required this.show});

  final TvShow show;

  @override
  Widget build(BuildContext context) {
    final url = showImageUrl(show.posterPath, 'original');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Hero(
                tag: 'show-poster-${show.id}',
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: url == null
                      ? const _ImageFallback(icon: Icons.tv_rounded)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: FlixieColors.primary,
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              const _ImageFallback(icon: Icons.tv_rounded),
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
                show.name,
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

class EpisodeStill extends StatelessWidget {
  const EpisodeStill({super.key, this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final url = showImageUrl(path, 'w500');
    if (url == null) {
      return const _ImageFallback(icon: Icons.play_circle_outline_rounded);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          const _ImageFallback(icon: Icons.play_circle_outline_rounded),
      errorWidget: (_, __, ___) =>
          const _ImageFallback(icon: Icons.play_circle_outline_rounded),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.colors.surface,
        child:
            Center(child: Icon(icon, color: context.colors.medium, size: 30)),
      );
}
