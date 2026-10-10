import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_insights.dart';
import 'group_insights_style.dart';

class InsightsPulseStrip extends StatelessWidget {
  const InsightsPulseStrip({super.key, required this.insights});

  final GroupInsightsResponse insights;

  @override
  Widget build(BuildContext context) {
    final monthlyWatches = insights.mostWatchedThisMonth.fold<int>(
      0,
      (total, movie) => total + movie.watchCount,
    );
    final discussionCount = insights.mostDiscussedMovies.fold<int>(
      0,
      (total, movie) => total + movie.discussionCount,
    );
    final ratingCount = insights.highestRatedMovies.fold<int>(
      0,
      (total, movie) => total + movie.ratingCount,
    );

    final tiles = [
      _PulseTile(
        label: 'Watches',
        value: '$monthlyWatches',
        icon: Icons.visibility_outlined,
        color: FlixieColors.primary,
      ),
      _PulseTile(
        label: 'Ratings',
        value: '$ratingCount',
        icon: Icons.star_rounded,
        color: context.colors.warning,
      ),
      _PulseTile(
        label: 'Reviews',
        value: '${insights.recentReviews.length}',
        icon: Icons.rate_review_outlined,
        color: context.colors.tertiary,
      ),
      _PulseTile(
        label: 'Messages',
        value: '$discussionCount',
        icon: Icons.forum_outlined,
        color: const Color(0xFF70A7FF),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: groupInsightsDecoration(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
          if (constraints.maxWidth < 300 * scale) {
            return Wrap(
              runSpacing: 16,
              children: [
                for (final tile in tiles)
                  SizedBox(width: constraints.maxWidth / 2, child: tile),
              ],
            );
          }
          return Row(
            children: [
              for (var index = 0; index < tiles.length; index++) ...[
                Expanded(child: tiles[index]),
                if (index != tiles.length - 1)
                  SizedBox(
                    height: 58,
                    child: VerticalDivider(
                      width: 1,
                      color: context.colors.tabBarBorder,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: context.colors.medium,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
