import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/movie_images.dart';
import 'movie_image_gallery.dart';

class MoviePhotosSection extends StatelessWidget {
  const MoviePhotosSection(
      {super.key,
      required this.movie,
      required this.images,
      required this.loading});
  final Movie movie;
  final MovieImages images;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlixieSectionHeader(title: 'Photos'),
          SizedBox(height: 10),
          SizedBox(
            height: 126,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  SkeletonBox(width: 224, height: 126, borderRadius: 14),
                  SizedBox(width: 10),
                  SkeletonBox(width: 224, height: 126, borderRadius: 14),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final images = this.images.gallery;
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const FlixieSectionHeader(title: 'Photos'),
            TextButton(
              onPressed: () => _openImageGrid(context, movie, images),
              child: Text(
                'See all (${images.length})',
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final image = images[index];
              final width = (126 * image.aspectRatio).clamp(84.0, 224.0);
              return Semantics(
                button: true,
                label: 'Open photo ${index + 1} of ${images.length}',
                child: InkWell(
                  onTap: () => _openImageGallery(context, movie, images, index),
                  borderRadius: BorderRadius.circular(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: image.thumbnailUrl,
                      width: width,
                      height: 126,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => SkeletonBox(
                        width: width,
                        height: 126,
                        borderRadius: 14,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: width,
                        height: 126,
                        color: context.colors.surface,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.colors.medium,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openImageGallery(
    BuildContext context,
    Movie movie,
    List<MovieImage> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: MovieImageGalleryViewer(
            movieTitle: movie.title,
            images: images,
            initialIndex: initialIndex,
          ),
        ),
      ),
    );
  }

  void _openImageGrid(
      BuildContext context, Movie movie, List<MovieImage> images) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MovieImageGridScreen(
          movieTitle: movie.title,
          images: images,
        ),
      ),
    );
  }
}
