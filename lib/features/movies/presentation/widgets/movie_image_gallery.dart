import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie_images.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class MovieImageGridScreen extends StatelessWidget {
  const MovieImageGridScreen({
    super.key,
    required this.movieTitle,
    required this.images,
  });

  final String movieTitle;
  final List<MovieImage> images;

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: MovieImageGalleryViewer(
            movieTitle: movieTitle,
            images: images,
            initialIndex: initialIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$movieTitle photos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${images.length} images',
              style: TextStyle(
                color: context.colors.medium,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700 ? 4 : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.25,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return Semantics(
                button: true,
                label: 'Open photo ${index + 1} of ${images.length}',
                child: InkWell(
                  onTap: () => _openViewer(context, index),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: image.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const SkeletonBox(borderRadius: 12),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: context.colors.surface,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: context.colors.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MovieImageGalleryViewer extends StatefulWidget {
  const MovieImageGalleryViewer({
    super.key,
    required this.movieTitle,
    required this.images,
    required this.initialIndex,
  });

  final String movieTitle;
  final List<MovieImage> images;
  final int initialIndex;

  @override
  State<MovieImageGalleryViewer> createState() =>
      MovieImageGalleryViewerState();
}

class MovieImageGalleryViewerState extends State<MovieImageGalleryViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final image = widget.images[index];
                return InteractiveViewer(
                  key: ValueKey(image.path),
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: image.originalUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                          color: FlixieColors.primary,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.colors.medium,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton.filledTonal(
                tooltip: 'Close photos',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .65),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              top: 14,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: TextStyle(
                      color: context.colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Text(
                widget.movieTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
