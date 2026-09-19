import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/similar_movie.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

class SimilarMovieCard extends StatelessWidget {
  const SimilarMovieCard({super.key, required this.movie});

  final SimilarMovie movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(movieDetailPath(movie.id)),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: 120,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: movie.posterPath != null
                  ? CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w342${movie.posterPath!}',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _posterFallback(context),
                    )
                  : _posterFallback(context),
            ),
            const SizedBox(height: 6),
            Text(
              movie.title,
              style: TextStyle(
                color: context.colors.light,
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

  Widget _posterFallback(BuildContext context) {
    return Container(
      color: context.colors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: context.colors.medium,
          size: 36,
        ),
      ),
    );
  }
}
