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
              : Column(
                  children: [
                    _Poster(data: data, accent: posterAccent),
                    Expanded(child: ReviewShareCardContent(data: data)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.data, required this.accent});

  final ShareCardData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 238,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [
                  accent.withValues(alpha: .28),
                  FlixieColors.surface,
                ],
              ),
            ),
          ),
          if (data.posterUrl != null)
            Align(
              alignment: Alignment.topCenter,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                child: CachedNetworkImage(
                  imageUrl: data.posterUrl!,
                  width: 159,
                  height: 238,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _posterFallback(),
                ),
              ),
            )
          else
            _posterFallback(),
          const Positioned(
            left: 18,
            top: 18,
            child: FlixieWordmark(fontSize: 21),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, FlixieColors.background],
                    stops: [.72, 1],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterFallback() => Center(
        child: Container(
          width: 159,
          height: 238,
          decoration: BoxDecoration(
            color: FlixieColors.surfaceElevated,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(18)),
            border:
                Border.all(color: FlixieColors.primary.withValues(alpha: .3)),
          ),
          child: const Icon(Icons.movie_outlined,
              size: 58, color: FlixieColors.medium),
        ),
      );
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
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 380,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.25),
                  radius: .82,
                  colors: [
                    posterAccent.withValues(alpha: .18),
                    FlixieColors.primary.withValues(alpha: .08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 20,
            top: 21,
            child: FlixieWordmark(fontSize: 22),
          ),
          Positioned(
            right: 20,
            top: 28,
            child: Text(
              data.recommended == false ? 'RATED' : 'RATED & RECOMMENDED',
              style: const TextStyle(
                color: FlixieColors.secondary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.1,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 73,
            height: 105,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.rating}.0',
                    style: const TextStyle(
                      color: FlixieColors.tertiary,
                      fontSize: 112,
                      height: .8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -8,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 6, bottom: 2),
                    child: Text(
                      '/10',
                      style: TextStyle(
                        color: FlixieColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 104,
            right: 104,
            top: 187,
            child: _SparkDivider(),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 205,
            height: 70,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 42,
                  height: .98,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                ),
              ),
            ),
          ),
          Positioned(
            left: 97,
            top: 282,
            width: 166,
            height: 249,
            child: _TallPoster(data: data, accent: posterAccent),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 537,
            child: Divider(
              height: 1,
              color: FlixieColors.primary.withValues(alpha: .55),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: 548,
            height: 82,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatarView(
                  avatar: data.avatar,
                  fallbackText: data.initials,
                  fallbackColor: Color(data.avatarColorValue),
                  profileBadges: data.profileBadges,
                  size: 46,
                ),
                const SizedBox(width: 13),
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
                              color: data.recommended!
                                  ? FlixieColors.secondary
                                  : FlixieColors.danger,
                              size: 17,
                            ),
                            const SizedBox(width: 7),
                          ],
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '@${data.username}',
                                    style: const TextStyle(
                                      color: FlixieColors.tertiary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: data.recommended == true
                                        ? ' recommends'
                                        : data.recommended == false
                                            ? " doesn't recommend"
                                            : ' rated this',
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlixieColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showNote && data.note != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '“',
                              style: TextStyle(
                                color: FlixieColors.secondary,
                                fontSize: 30,
                                height: .7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                data.note!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FlixieColors.textPrimary,
                                  fontSize: 14,
                                  height: 1.12,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        border: Border.all(
          color: Color.alphaBlend(
            accent.withValues(alpha: .75),
            FlixieColors.primary,
          ),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .17),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
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

class _SparkDivider extends StatelessWidget {
  const _SparkDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: FlixieColors.primary, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Icon(Icons.auto_awesome_rounded,
              color: FlixieColors.primary, size: 15),
        ),
        Expanded(child: Divider(color: FlixieColors.primary, height: 1)),
      ],
    );
  }
}

class ReviewShareCardContent extends StatelessWidget {
  const ReviewShareCardContent({super.key, required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _UserRow(data: data)),
              const Icon(Icons.star_rounded,
                  color: FlixieColors.tertiary, size: 22),
              const SizedBox(width: 3),
              Text('${data.rating}/10',
                  style: const TextStyle(
                    color: FlixieColors.tertiary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          const SizedBox(height: 11),
          Text(data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
          if (data.reviewTitle != null) ...[
            const SizedBox(height: 6),
            Text(data.reviewTitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 24,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                )),
          ],
          if (data.reviewExcerpt != null) ...[
            const SizedBox(height: 11),
            _Quote(text: data.reviewExcerpt!, maxLines: 5),
          ],
          const Spacer(),
          _RecommendationStatus(value: data.recommended),
          const SizedBox(height: 13),
          const _Footer(readOnFlixie: true),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileAvatarView(
          avatar: data.avatar,
          fallbackText: data.initials,
          fallbackColor: Color(data.avatarColorValue),
          profileBadges: data.profileBadges,
          size: 34,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(data.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );
  }
}

class _RecommendationStatus extends StatelessWidget {
  const _RecommendationStatus({required this.value});

  final bool? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    final recommends = value!;
    final color = recommends ? FlixieColors.success : FlixieColors.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
            recommends
                ? Icons.thumb_up_alt_rounded
                : Icons.thumb_down_alt_rounded,
            color: color,
            size: 21),
        const SizedBox(width: 8),
        Text(recommends ? 'Recommends' : "Doesn't recommend",
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.text, required this.maxLines});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: .23)),
      ),
      child: Text(text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FlixieColors.textPrimary,
            fontSize: 14,
            height: 1.3,
          )),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({this.readOnFlixie = false});

  final bool readOnFlixie;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const FlixieWordmark(fontSize: 18),
        const SizedBox(width: 12),
        if (readOnFlixie)
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text('Read on Flixie',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: FlixieColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    color: FlixieColors.secondary, size: 15),
              ],
            ),
          )
        else
          const Expanded(
            child: Text('What are you watching?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(color: FlixieColors.medium, fontSize: 11)),
          ),
      ],
    );
  }
}
