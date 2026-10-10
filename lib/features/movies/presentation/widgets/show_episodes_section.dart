import 'package:flixie_app/features/movies/presentation/widgets/show_episode_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_images.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class ShowEpisodesSection extends StatelessWidget {
  const ShowEpisodesSection(
      {super.key,
      required this.show,
      required this.selectedSeason,
      required this.updatingSeasons,
      required this.updatingEpisodes,
      required this.hideSpoilers,
      required this.savingSpoilers,
      required this.loading,
      required this.loaded,
      required this.failed,
      required this.onRetry,
      required this.onSeasonSelected,
      required this.onSpoilersChanged,
      required this.onSeasonWatched,
      required this.onEpisodeWatched,
      required this.onOpenEpisode});
  final TvShow show;
  final int? selectedSeason;
  final Set<int> updatingSeasons;
  final Set<int> updatingEpisodes;
  final bool hideSpoilers;
  final bool savingSpoilers;
  final bool loading;
  final bool loaded;
  final bool failed;
  final VoidCallback onRetry;
  final ValueChanged<int> onSeasonSelected;
  final ValueChanged<bool> onSpoilersChanged;
  final void Function(TvSeason, bool) onSeasonWatched;
  final void Function(TvEpisode, bool) onEpisodeWatched;
  final ValueChanged<TvEpisode> onOpenEpisode;
  @override
  Widget build(BuildContext context) {
    final show = this.show;
    if (!loaded && (loading || failed)) {
      return ShowEpisodeLoadingState(loading: loading, onRetry: onRetry);
    }
    if (show.seasons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
            'Episode details are not available yet. Pull down to refresh.',
            style: TextStyle(color: context.colors.light)),
      );
    }
    final seasonNumber = selectedSeason ?? show.seasons.first.seasonNumber;
    final selected =
        show.seasons.where((s) => s.seasonNumber == seasonNumber).firstOrNull ??
            show.seasons.first;
    final episodes = show.episodesForSeason(selected.seasonNumber);
    final progress = TvShowEpisodeProgress(show);
    final nextEpisodeId = progress.nextReleased?.id;
    final released = episodes.where(progress.isReleased).toList();
    final complete =
        released.isNotEmpty && released.every((episode) => episode.watched);
    final busy = updatingSeasons.contains(selected.seasonNumber);
    // Season labels can wrap; match their actual scaled height rather than
    // assuming a single line under the poster.
    final labelHeight = show.seasons.map((season) {
      final painter = TextPainter(
          text: TextSpan(
              text: season.seasonNumber == 0
                  ? 'Specials'
                  : 'Season ${season.seasonNumber}',
              style: DefaultTextStyle.of(context).style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context))
        ..layout(maxWidth: 96);
      final height = painter.height;
      painter.dispose();
      return height;
    }).reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 152 + labelHeight,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: show.seasons.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final season = show.seasons[index];
              final active = selected.seasonNumber == season.seasonNumber;
              return Semantics(
                  selected: active,
                  button: true,
                  child: InkWell(
                      onTap: () => onSeasonSelected(season.seasonNumber),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                          width: 96,
                          child: Column(children: [
                            Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: active
                                            ? FlixieColors.primary
                                            : Colors.transparent,
                                        width: 2)),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                        height: 128,
                                        width: 86,
                                        child: ShowPoster(
                                            path: season.posterPath ??
                                                show.posterPath)))),
                            const SizedBox(height: 6),
                            Text(
                                season.seasonNumber == 0
                                    ? 'Specials'
                                    : 'Season ${season.seasonNumber}',
                                style: TextStyle(
                                    color: active
                                        ? context.colors.textPrimary
                                        : context.colors.light)),
                          ]))));
            }),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Hide spoilers'),
        value: hideSpoilers,
        onChanged: savingSpoilers ? null : onSpoilersChanged,
      ),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FlixieSectionHeader(
                    title: selected.seasonNumber == 0
                        ? 'Specials'
                        : 'Season ${selected.seasonNumber}'),
                Text(
                    '${selected.watchedEpisodeCount} of ${selected.resolvedEpisodeCount} watched',
                    style:
                        TextStyle(color: context.colors.light, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: busy || released.isEmpty
                    ? null
                    : () => onSeasonWatched(selected, !complete),
                child: Text(
                    busy
                        ? 'Saving…'
                        : complete
                            ? 'Mark season\nunwatched'
                            : 'Mark season\nwatched',
                    textAlign: TextAlign.right),
              ),
            ),
          ),
        ],
      ),
      Divider(color: context.colors.tabBarBorder),
      if (episodes.isEmpty)
        Text('No episodes available yet.',
            style: TextStyle(color: context.colors.light)),
      for (final episode in episodes)
        ShowEpisodeCard(
            isNext: nextEpisodeId == episode.id,
            hideSpoilers: hideSpoilers && !episode.watched,
            episode: episode,
            isUpdating: busy || updatingEpisodes.contains(episode.id),
            onOpen: () => onOpenEpisode(episode),
            onToggleWatched: () => onEpisodeWatched(episode, !episode.watched)),
    ]);
  }
}

class ShowEpisodeLoadingState extends StatelessWidget {
  const ShowEpisodeLoadingState(
      {super.key, required this.loading, required this.onRetry});
  final bool loading;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const ContentPlaceholder(
          label: 'Loading episodes and progress', rows: 2);
    }
    return Row(children: [
      const Expanded(child: Text('Episodes and progress couldn’t load.')),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]);
  }
}
