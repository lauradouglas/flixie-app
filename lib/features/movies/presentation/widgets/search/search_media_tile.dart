import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'search_content.dart';

class SearchMediaTile extends StatelessWidget {
  const SearchMediaTile._({
    required this.name,
    required this.posterPath,
    required this.year,
    required this.overview,
    required this.rating,
    required this.mediaId,
    required this.isShow,
    required this.query,
    this.onTap,
  });

  factory SearchMediaTile.movie({
    required MovieShort movie,
    required String query,
    VoidCallback? onTap,
  }) =>
      SearchMediaTile._(
        mediaId: movie.id,
        name: movie.name,
        posterPath: movie.poster,
        year: searchReleaseYear(movie.releaseDate),
        overview: movie.overview,
        rating: movie.voteAverage,
        isShow: false,
        query: query,
        onTap: onTap,
      );

  factory SearchMediaTile.show({
    required TvShow show,
    required String query,
    VoidCallback? onTap,
  }) =>
      SearchMediaTile._(
        mediaId: show.id,
        name: show.name,
        posterPath: show.posterPath,
        year: searchReleaseYear(show.firstAirDate),
        overview: show.overview,
        rating: show.voteAverage,
        isShow: true,
        query: query,
        onTap: onTap,
      );

  final String name;
  final String? posterPath;
  final String? year;
  final String? overview;
  final double? rating;
  final int mediaId;
  final bool isShow;
  final String query;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: .07)),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 67,
                  height: 100,
                  child: posterPath == null
                      ? _MediaPlaceholder(isShow: isShow)
                      : CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w185$posterPath',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _MediaPlaceholder(isShow: isShow),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SearchHighlightedText(
                      text: name,
                      query: query,
                      baseStyle: TextStyle(
                        color: context.colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 11,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FlixiePill.label(
                          label: Text(isShow ? 'Show' : 'Movie'),
                        ),
                        if (year != null)
                          Text(
                            year!,
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 13,
                            ),
                          ),
                        if (!hideMovieRatings(
                              context,
                              mediaId,
                              isShow: isShow,
                            ) &&
                            rating != null &&
                            rating! > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: context.colors.warning,
                                size: 17,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  color: context.colors.medium,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if ((overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.light,
                          fontSize: 12.5,
                          height: 1.28,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: context.colors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.isShow});
  final bool isShow;

  @override
  Widget build(BuildContext context) => Container(
        color: context.colors.surfaceElevated,
        child: Icon(
          isShow ? Icons.live_tv_rounded : Icons.movie_outlined,
          color: context.colors.medium,
        ),
      );
}
