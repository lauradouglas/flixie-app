import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/show.dart';

class ShowViewingTimeline extends StatelessWidget {
  const ShowViewingTimeline(
      {super.key,
      required this.show,
      required this.hideSpoilers,
      required this.busy,
      required this.onMarkWatched,
      required this.onOpenEpisode,
      required this.onViewEpisodes,
      this.now});
  final TvShow show;
  final bool hideSpoilers, busy;
  final VoidCallback? onMarkWatched;
  final ValueChanged<TvEpisode> onOpenEpisode;
  final VoidCallback onViewEpisodes;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final progress = TvShowEpisodeProgress(show, now: clock);
    final episode = progress.nextReleased ?? progress.nextScheduled;
    final logged = progress.allEpisodes.where((e) => e.watched).toList();
    final dated = logged
        .where((e) => e.watchedAt != null && !e.watchedAt!.isAfter(clock))
        .toList()
      ..sort((a, b) => b.watchedAt!.compareTo(a.watchedAt!));
    // Dates describe log history, not the furthest watched position. Bulk
    // season saves may share a date, and older imported progress may lack one.
    logged.sort((a, b) {
      final season = a.seasonNumber.compareTo(b.seasonNumber);
      return season != 0 ? season : a.episodeNumber.compareTo(b.episodeNumber);
    });
    final last = logged.lastOrNull;
    final returning = progress.nextReleased != null &&
        dated.isNotEmpty &&
        clock.difference(dated.first.watchedAt!) >= const Duration(days: 90);
    final title = progress.nextReleased == null
        ? progress.nextLabel
        : returning
            ? 'Your place, saved'
            : progress.hasStarted
                ? 'Continue watching'
                : 'Start watching';
    final season = episode?.seasonNumber;
    final seasonEpisodes = progress.releasedEpisodes
        .where((e) => season == null || e.seasonNumber == season)
        .toList();
    final watched = seasonEpisodes.where((e) => e.watched).length;
    String position(TvEpisode e) =>
        'Season ${e.seasonNumber} · Episode ${e.episodeNumber}';
    final label = last != null
        ? 'Last watched · ${position(last)}'
        : episode != null
            ? 'First up · ${position(episode)}'
            : 'Your viewing progress';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          border: Border.all(color: context.colors.tabBarBorder),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: context.colors.white,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w700)),
        if (returning)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'Your last episode was logged on ${dated.first.watchedAt!.day}/${dated.first.watchedAt!.month}/${dated.first.watchedAt!.year}.',
                  style: TextStyle(color: context.colors.light, height: 1.5))),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: context.colors.primaryText,
                      shape: BoxShape.circle))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: context.colors.light, fontSize: 12))),
        ]),
        if (episode != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              decoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(color: context.colors.tabBarBorder))),
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
              child: InkWell(
                  onTap: () => onOpenEpisode(episode),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(position(episode),
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 5),
                            Text(
                                hideSpoilers && !episode.watched
                                    ? 'Episode title hidden'
                                    : episode.name,
                                style: TextStyle(color: context.colors.light)),
                            if (episode.runtime != null)
                              Text('${episode.runtime} min',
                                  style: TextStyle(
                                      color: context.colors.light,
                                      fontSize: 12)),
                            if (progress.nextReleased == null &&
                                episode.airDate != null)
                              Text('Expected ${episode.airDate}',
                                  style: TextStyle(
                                      color: context.colors.light,
                                      fontSize: 12)),
                          ]))),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (progress.nextReleased != null)
                FilledButton.icon(
                    onPressed: busy ? null : onMarkWatched,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11))),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(busy ? 'Saving…' : 'Mark watched')),
              TextButton(
                  onPressed: onViewEpisodes,
                  child: Text(returning ? 'Check my place' : 'View episodes')),
            ]),
        if (seasonEpisodes.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '$watched of ${seasonEpisodes.length} watched${season == null ? '' : ' this season'}',
                  style: TextStyle(color: context.colors.light, fontSize: 12))),
      ]),
    );
  }
}
