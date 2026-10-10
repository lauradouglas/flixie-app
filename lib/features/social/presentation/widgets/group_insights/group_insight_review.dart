import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_insights.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'group_insights_style.dart';

class InsightReviewCard extends StatefulWidget {
  const InsightReviewCard({super.key, required this.review});

  final GroupInsightReview review;

  @override
  State<InsightReviewCard> createState() => _InsightReviewCardState();
}

class _InsightReviewCardState extends State<InsightReviewCard> {
  static const _posterBase = 'https://image.tmdb.org/t/p/w185';
  bool _spoilerRevealed = false;

  @override
  void didUpdateWidget(covariant InsightReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id ||
        oldWidget.review.userId != widget.review.userId ||
        oldWidget.review.snippet != widget.review.snippet ||
        oldWidget.review.containsSpoilers != widget.review.containsSpoilers) {
      _spoilerRevealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final posterUrl = insightsPosterUrl(review.moviePosterPath, _posterBase);
    final handle = review.reviewerUsername.trim().isEmpty
        ? review.reviewerName
        : '@${review.reviewerUsername.trim()}';
    final profileAction = review.userId != null && review.userId!.isNotEmpty
        ? () => context.push('/friends/${review.userId}')
        : null;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: review.movieId != null
                ? () => context.push(movieDetailPath(review.movieId!))
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 62,
                height: 92,
                child: posterUrl == null
                    ? Container(
                        color: context.colors.tabBarBorder,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 20,
                          color: context.colors.medium,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: context.colors.tabBarBorder,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.movie_outlined,
                            size: 20,
                            color: context.colors.medium,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: profileAction,
                      child: ProfileAvatarView(
                        avatar: review.reviewerAvatar,
                        fallbackText: review.reviewerName.isEmpty
                            ? '?'
                            : review.reviewerName[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 28,
                        profileBadges: review.reviewerProfileBadges,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: profileAction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              handle,
                              style: TextStyle(
                                color: context.colors.light,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              insightsRelativeDate(review.createdAt),
                              style: TextStyle(
                                color: context.colors.medium,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: review.movieId != null
                      ? () => context.push(movieDetailPath(review.movieId!))
                      : null,
                  child: Text(
                    review.movieTitle,
                    style: TextStyle(
                      color: context.colors.light,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFFC34D),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      hideMovieRatings(
                        context,
                        review.movieId,
                        ownerId: review.userId,
                      )
                          ? 'Rate to see score'
                          : '${review.rating.toStringAsFixed(1)}/10',
                      style: TextStyle(
                        color: context.colors.light,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (review.recommended != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        review.recommended!
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_down_alt_rounded,
                        size: 14,
                        color: review.recommended!
                            ? const Color(0xFF55D69E)
                            : context.colors.medium,
                      ),
                    ],
                    if (review.containsSpoilers) ...[
                      const Text(
                        'SPOILER',
                        style: TextStyle(
                          color: Color(0xFFFFC34D),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ],
                ),
                if (review.snippet.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: review.containsSpoilers && !_spoilerRevealed
                        ? () => setState(() => _spoilerRevealed = true)
                        : null,
                    child: Text(
                      review.containsSpoilers && !_spoilerRevealed
                          ? 'Tap to reveal review'
                          : review.snippet.trim(),
                      style: TextStyle(
                        color: review.containsSpoilers && !_spoilerRevealed
                            ? FlixieColors.primary
                            : context.colors.medium,
                        height: 1.25,
                        fontSize: 12,
                        fontStyle: review.containsSpoilers && !_spoilerRevealed
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
