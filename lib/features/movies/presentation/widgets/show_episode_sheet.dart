import 'package:flixie_app/features/movies/presentation/utils/show_image_url.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

void showShowEpisodeSheet(BuildContext context, TvEpisode episode,
    {required VoidCallback onToggleWatched}) {
  final still = showImageUrl(episode.stillPath, 'w780');
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.colors.background,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: still == null
                        ? ColoredBox(color: context.colors.surface)
                        : CachedNetworkImage(
                            imageUrl: still,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            context.colors.background.withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 12,
                    child: IconButton.filled(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.42),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Season ${episode.seasonNumber} · Episode ${episode.episodeNumber}',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      episode.name,
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _EpisodeInfoChip(
                          icon: Icons.calendar_month_rounded,
                          label: _dateLabel(episode.airDate),
                        ),
                        if (episode.runtime != null)
                          _EpisodeInfoChip(
                            icon: Icons.schedule_rounded,
                            label: '${episode.runtime}m',
                          ),
                        if (episode.voteAverage != null)
                          _EpisodeInfoChip(
                            icon: Icons.star_rounded,
                            label:
                                '${episode.voteAverage!.toStringAsFixed(1)}/10',
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _CompactPillButton(
                      icon: episode.watched
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      label:
                          episode.watched ? 'Mark unwatched' : 'Mark watched',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onToggleWatched();
                      },
                    ),
                    if ((episode.overview ?? '').isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text(
                        'Overview',
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        episode.overview!,
                        style: TextStyle(
                          color: context.colors.light,
                          fontSize: 15,
                          height: 1.42,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _CompactPillButton extends StatelessWidget {
  const _CompactPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.action(
        label: Text(label), avatar: Icon(icon), onPressed: onTap);
  }
}

class _EpisodeInfoChip extends StatelessWidget {
  const _EpisodeInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.label(label: Text(label), avatar: Icon(icon));
  }
}

String _dateLabel(String? date) {
  if (date == null || date.isEmpty) return '-';
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}
