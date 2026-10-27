import 'package:cached_network_image/cached_network_image.dart';
import '../../models/rating_card_style.dart';
import 'rating_share_card.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';

class FlixieShareCard extends StatelessWidget {
  const FlixieShareCard({
    super.key,
    required this.data,
    this.posterAccent = FlixieColors.primary,
    this.showNote = true,
    this.quote,
    this.style = RatingCardStyle.fullStory,
    this.background = RatingCardBackground.transparent,
    this.pip,
    this.posterProvider,
    this.onArtworkReady,
  });

  final ShareCardData data;
  final Color posterAccent;
  final bool showNote;
  final String? quote;
  final RatingCardStyle style;
  final RatingCardBackground background;
  final String? pip;
  final ImageProvider? posterProvider;
  final ValueChanged<bool>? onArtworkReady;

  @override
  Widget build(BuildContext context) {
    if (data.variant == ShareCardVariant.rating) {
      return RatingShareCard(
          data: data,
          style: style,
          background: background,
          pip: pip,
          showNote: showNote,
          quote: quote,
          posterProvider: posterProvider,
          onArtworkReady: onArtworkReady);
    }
    return Material(
      color: context.colors.background,
      child: SizedBox(
        width: 360,
        height: 640,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  posterAccent.withValues(alpha: .16),
                  context.colors.background,
                ),
                context.colors.background,
                context.colors.background,
              ],
              stops: const [0, .46, 1],
            ),
          ),
          child: ReviewShareCardContent(data: data, posterAccent: posterAccent),
        ),
      ),
    );
  }
}

class _TallPoster extends StatelessWidget {
  const _TallPoster({required this.data, required this.accent});

  final ShareCardData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final url = data.posterUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: url == null
            ? Icon(Icons.movie_outlined, size: 55, color: context.colors.medium)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(Icons.movie_outlined,
                    size: 55, color: context.colors.medium),
              ),
      ),
    );
  }
}

class ReviewShareCardContent extends StatelessWidget {
  const ReviewShareCardContent({
    super.key,
    required this.data,
    required this.posterAccent,
  });

  final ShareCardData data;
  final Color posterAccent;

  @override
  Widget build(BuildContext context) {
    final recommendationColor = data.recommended == true
        ? context.colors.secondary
        : data.recommended == false
            ? context.colors.danger
            : context.colors.medium;
    final recommendationLabel = data.neutralRecommendation
        ? 'has no recommendation'
        : data.recommended == true
            ? 'recommends this'
            : data.recommended == false
                ? "doesn't recommend this"
                : 'rated this';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -.72),
          radius: 1.05,
          colors: [
            posterAccent.withValues(alpha: .16),
            context.colors.background,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FlixieWordmark(
                    fontSize: 22, foregroundColor: Colors.white),
                const Spacer(),
                Text(
                  data.recommended == true ? 'RECOMMENDED' : 'RATED',
                  style: TextStyle(
                    color: data.recommended == true
                        ? context.colors.secondary
                        : context.colors.medium,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.rating}',
                  style: TextStyle(
                    color: context.colors.tertiary,
                    fontSize: 76,
                    height: .8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -4,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5, bottom: 2),
                  child: Text(
                    '/10',
                    style: TextStyle(
                      color: context.colors.light,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 30,
                height: 1.02,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 124,
                height: 186,
                child: _TallPoster(data: data, accent: posterAccent),
              ),
            ),
            const Spacer(),
            Divider(color: context.colors.light.withValues(alpha: .2)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatarView(
                  avatar: data.avatar,
                  fallbackText: data.initials,
                  fallbackColor: Color(data.avatarColorValue),
                  profileBadges: data.profileBadges,
                  size: 42,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (data.recommended != null ||
                              data.neutralRecommendation) ...[
                            Icon(
                              data.neutralRecommendation
                                  ? Icons.remove_rounded
                                  : data.recommended!
                                      ? Icons.thumb_up_alt_rounded
                                      : Icons.thumb_down_alt_rounded,
                              color: recommendationColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '@${data.username} ',
                                    style: TextStyle(
                                      color: context.colors.tertiary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(text: recommendationLabel),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (data.reviewTitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          data.reviewTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (data.reviewExcerpt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          data.reviewExcerpt!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.light,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
