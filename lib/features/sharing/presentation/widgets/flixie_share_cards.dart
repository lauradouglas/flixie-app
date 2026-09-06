import 'package:cached_network_image/cached_network_image.dart';
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
  });

  final ShareCardData data;
  final Color posterAccent;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlixieColors.background,
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
                  FlixieColors.background,
                ),
                FlixieColors.background,
                FlixieColors.background,
              ],
              stops: const [0, .46, 1],
            ),
          ),
          child: data.variant == ShareCardVariant.rating
              ? RatingShareCardContent(
                  data: data,
                  posterAccent: posterAccent,
                  showNote: showNote,
                )
              : ReviewShareCardContent(
                  data: data,
                  posterAccent: posterAccent,
                ),
        ),
      ),
    );
  }
}

class RatingShareCardContent extends StatelessWidget {
  const RatingShareCardContent({
    super.key,
    required this.data,
    this.posterAccent = FlixieColors.primary,
    this.showNote = true,
  });

  final ShareCardData data;
  final Color posterAccent;
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    final posterHeight = showNote && data.note != null ? 300.0 : 330.0;
    final recommendationColor = data.recommended == true
        ? FlixieColors.secondary
        : data.recommended == false
            ? FlixieColors.danger
            : FlixieColors.medium;
    final recommendationLabel = data.recommended == true
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
            FlixieColors.background,
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
                const FlixieWordmark(fontSize: 22),
                const Spacer(),
                Text(
                  data.recommended == true ? 'RECOMMENDED' : 'RATED',
                  style: TextStyle(
                    color: data.recommended == true
                        ? FlixieColors.secondary
                        : FlixieColors.medium,
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
                  '${data.rating}.0',
                  style: const TextStyle(
                    color: FlixieColors.tertiary,
                    fontSize: 76,
                    height: .8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -4,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 5, bottom: 2),
                  child: Text(
                    '/10',
                    style: TextStyle(
                      color: FlixieColors.light,
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
              style: const TextStyle(
                color: FlixieColors.textPrimary,
                fontSize: 30,
                height: 1.02,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: posterHeight * (2 / 3),
                height: posterHeight,
                child: _TallPoster(data: data, accent: posterAccent),
              ),
            ),
            const Spacer(),
            Divider(color: FlixieColors.light.withValues(alpha: .2)),
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
                          if (data.recommended != null) ...[
                            Icon(
                              data.recommended!
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
                                    style: const TextStyle(
                                      color: FlixieColors.tertiary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(text: recommendationLabel),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlixieColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showNote && data.note != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          data.note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 13,
                            height: 1.25,
                            fontStyle: FontStyle.italic,
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

class _TallPoster extends StatelessWidget {
  const _TallPoster({required this.data, required this.accent});

  final ShareCardData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final url = data.posterUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: url == null
            ? const Icon(Icons.movie_outlined,
                size: 55, color: FlixieColors.medium)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.movie_outlined,
                    size: 55, color: FlixieColors.medium),
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
        ? FlixieColors.secondary
        : data.recommended == false
            ? FlixieColors.danger
            : FlixieColors.medium;
    final recommendationLabel = data.recommended == true
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
            FlixieColors.background,
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
                const FlixieWordmark(fontSize: 22),
                const Spacer(),
                Text(
                  data.recommended == true ? 'RECOMMENDED' : 'RATED',
                  style: TextStyle(
                    color: data.recommended == true
                        ? FlixieColors.secondary
                        : FlixieColors.medium,
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
                  '${data.rating}.0',
                  style: const TextStyle(
                    color: FlixieColors.tertiary,
                    fontSize: 76,
                    height: .8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -4,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 5, bottom: 2),
                  child: Text(
                    '/10',
                    style: TextStyle(
                      color: FlixieColors.light,
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
              style: const TextStyle(
                color: FlixieColors.textPrimary,
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
            Divider(color: FlixieColors.light.withValues(alpha: .2)),
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
                          if (data.recommended != null) ...[
                            Icon(
                              data.recommended!
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
                                    style: const TextStyle(
                                      color: FlixieColors.tertiary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(text: recommendationLabel),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlixieColors.textPrimary,
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
                          style: const TextStyle(
                            color: FlixieColors.textPrimary,
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
                          style: const TextStyle(
                            color: FlixieColors.light,
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
