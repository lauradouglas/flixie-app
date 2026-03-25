import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/similar_movie.dart';
import '../../theme/app_theme.dart';

class SimilarMovieCard extends StatelessWidget {
  const SimilarMovieCard({super.key, required this.movie});

  final SimilarMovie movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/movies/${movie.id}'),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E42),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: movie.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w342${movie.posterPath!}',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _posterFallback(),
                    )
                  : _posterFallback(),
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: FlixieColors.medium,
          size: 36,
        ),
      ),
    );
  }
}
