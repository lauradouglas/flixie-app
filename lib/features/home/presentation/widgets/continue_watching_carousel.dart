import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/continue_watching_show.dart';

class ContinueWatchingCarousel extends StatelessWidget {
  const ContinueWatchingCarousel({
    super.key,
    required this.shows,
    required this.onTap,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<ContinueWatchingShow> shows;
  final ValueChanged<ContinueWatchingShow> onTap;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: contentPadding,
        itemCount: shows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final show = shows[index];
          return ContinueWatchingCard(
            show: show,
            onTap: () => onTap(show),
          );
        },
      ),
    );
  }
}

class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({
    super.key,
    required this.show,
    required this.onTap,
  });

  final ContinueWatchingShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        (MediaQuery.sizeOf(context).width * .46).clamp(164.0, 230.0);
    final episode = show.lastWatchedEpisode;
    final episodeLabel = episode == null
        ? '${show.watchedEpisodes} episodes watched'
        : 'S${episode.seasonNumber} E${episode.episodeNumber}';
    final progress = (show.completionPercent / 100).clamp(0.0, 1.0);
    final imagePath = show.backdropPath ?? show.posterPath;
    final posterUrl =
        imagePath == null ? null : 'https://image.tmdb.org/t/p/w780$imagePath';

    return SizedBox(
      width: cardWidth,
      height: 102,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                posterUrl == null
                    ? _fallback()
                    : CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _fallback(),
                        errorWidget: (_, __, ___) => _fallback(),
                      ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [.3, 1],
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .68),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .24),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        show.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        episodeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.black54,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        FlixieColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: FlixieColors.tabBarBackgroundFocused,
        alignment: Alignment.center,
        child: const Icon(
          Icons.tv_rounded,
          color: FlixieColors.medium,
          size: 34,
        ),
      );
}
