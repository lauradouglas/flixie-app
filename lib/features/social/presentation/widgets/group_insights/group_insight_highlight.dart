import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/group_insights.dart';
import 'group_insights_style.dart';
import 'group_insight_watchers.dart';

class InsightHighlightCard extends StatelessWidget {
  const InsightHighlightCard({super.key, required this.movie});
  final GroupInsightMovie movie;

  @override
  Widget build(BuildContext context) {
    final url = insightsPosterUrl(
      movie.posterPath,
      'https://image.tmdb.org/t/p/w342',
    );
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 118,
        height: 164,
        child: url == null
            ? _placeholder(context)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(context),
              ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          movie.title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 20,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        const FlixiePill.label(label: Text('#1 in your group')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 5,
          children: [
            Text(
              '${movie.watchCount} watches',
              style: TextStyle(color: context.colors.light, fontSize: 11),
            ),
            Text(
              '${movie.discussionCount} discussions',
              style: TextStyle(color: context.colors.light, fontSize: 11),
            ),
            if (movie.averageRating > 0 &&
                !hideMovieRatings(context, movie.movieId))
              Text(
                '${movie.averageRating.toStringAsFixed(1)}/10',
                style: TextStyle(
                  color: context.colors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        if (movie.watchers.isNotEmpty) ...[
          const SizedBox(height: 11),
          GroupInsightWatchers(watchers: movie.watchers),
        ],
      ],
    );
    return InkWell(
      onTap: movie.movieId == null
          ? null
          : () => context.push(movieDetailPath(movie.movieId!)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: groupInsightsDecoration(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            if (constraints.maxWidth < 300 || scale > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [poster, const SizedBox(height: 14), details],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                poster,
                const SizedBox(width: 14),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
        color: context.colors.surfaceElevated,
        child: Icon(Icons.movie_outlined, color: context.colors.medium),
      );
}
