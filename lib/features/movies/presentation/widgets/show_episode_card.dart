import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/show.dart';
import 'show_detail_images.dart';

class ShowEpisodeCard extends StatelessWidget {
  const ShowEpisodeCard(
      {super.key,
      required this.episode,
      this.hideSpoilers = false,
      this.isNext = false,
      required this.onOpen,
      required this.onToggleWatched,
      required this.isUpdating});
  final TvEpisode episode;
  final bool hideSpoilers;
  final bool isNext;
  final VoidCallback onOpen, onToggleWatched;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(episode.airDate ?? '');
    final upcoming = date != null && date.isAfter(DateTime.now());
    return ColoredBox(
        color: isNext ? context.colors.surfaceElevated : Colors.transparent,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Expanded(
                    child: InkWell(
                        onTap: onOpen,
                        child: Row(children: [
                          SizedBox(
                              width: 74,
                              height: 56,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: hideSpoilers
                                      ? ColoredBox(
                                          color: context.colors.surface,
                                          child: Icon(
                                              Icons.visibility_off_outlined,
                                              color: context.colors.light))
                                      : EpisodeStill(path: episode.stillPath))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    '${isNext ? 'Up next · ' : ''}Episode ${episode.episodeNumber}',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                    hideSpoilers
                                        ? 'Title hidden'
                                        : episode.name,
                                    style: TextStyle(
                                        color: context.colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 5),
                                Text(
                                    upcoming
                                        ? 'Upcoming · ${episode.airDate}'
                                        : episode.runtime != null
                                            ? '${episode.runtime} min'
                                            : episode.watched
                                                ? 'Watched'
                                                : 'Not watched',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        fontSize: 12)),
                              ])),
                        ]))),
                const SizedBox(width: 8),
                if (isUpdating)
                  const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))))
                else
                  Semantics(
                      label: 'Episode ${episode.episodeNumber} watched',
                      child: Checkbox(
                          value: episode.watched,
                          onChanged: upcoming ? null : (_) => onToggleWatched(),
                          activeColor: FlixieColors.primary,
                          shape: const CircleBorder(),
                          materialTapTargetSize: MaterialTapTargetSize.padded)),
              ])),
          Divider(height: 1, color: context.colors.tabBarBorder),
        ]));
  }
}
