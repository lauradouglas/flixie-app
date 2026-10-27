import 'home_tablet_layout.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/movie_short.dart';
import '../models/home_image_urls.dart';
import '../models/home_section.dart';
import 'home_hero_card.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';

/// A selected film and browsable posters replace the oversized phone carousel.
class TabletTrendingGallery extends StatefulWidget {
  const TabletTrendingGallery(
      {super.key,
      required this.movies,
      this.friendActivity,
      this.onPageChanged,
      this.onFriendsRetry,
      required this.savedIds,
      required this.pendingIds,
      required this.onDetails,
      required this.onSave,
      required this.onTrailer});
  final HomeSection<List<FriendMediaInteraction>> Function(int)? friendActivity;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<MovieShort>? onFriendsRetry;
  final List<MovieShort> movies;
  final Set<int> savedIds, pendingIds;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;

  @override
  State<TabletTrendingGallery> createState() => _TabletTrendingGalleryState();
}

class _TabletTrendingGalleryState extends State<TabletTrendingGallery> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies.take(20).toList(growable: false);
    if (movies.isEmpty) return const SizedBox.shrink();
    final movie = movies.where((m) => m.homeKey == _selectedId).firstOrNull ??
        movies.first;
    final hidden = context.select<MovieRatingPrivacy?, bool>(
        (p) => p?.hides(movie.id, isShow: movie.isShow) ?? false);
    final compact = HomeTabletLayout.trendingActive(context);
    final railMovies = compact
        ? movies
            .where((item) => item.homeKey != movie.homeKey)
            .toList(growable: false)
        : movies;
    final saved = widget.savedIds.contains(movie.homeKey);
    final pending = widget.pendingIds.contains(movie.homeKey);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (compact)
          _compactFeature(context, movie,
              hidden: hidden, saved: saved, pending: pending)
        else
          Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: compact ? 130 : 160,
                    child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: _poster(context, movie,
                            onTap: () => widget.onDetails(movie)))),
                SizedBox(width: compact ? 18 : 24),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(movie.isShow ? 'TV show' : 'Movie',
                          style: TextStyle(
                              fontSize: 12, color: context.colors.medium)),
                      TextButton(
                        onPressed: () => widget.onDetails(movie),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            foregroundColor: context.colors.white),
                        child: Text(movie.name,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.12)),
                      ),
                      if (movie.releaseDate?.isNotEmpty == true)
                        Text(movie.releaseDate!.split('-').first,
                            style: TextStyle(color: context.colors.light)),
                      if (!hidden && (movie.voteAverage ?? 0) > 0) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.star_rounded,
                              color: context.colors.warning, size: 20),
                          const SizedBox(width: 6),
                          Text(movie.voteAverage!.toStringAsFixed(1),
                              style: TextStyle(
                                  color: context.colors.warning,
                                  fontWeight: FontWeight.w700))
                        ]),
                      ],
                      if (movie.overview?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Text(
                            compact
                                ? movie.overview!
                                    .split(RegExp(r'(?<=[.!?])\s+'))
                                    .first
                                : movie.overview!,
                            style: TextStyle(
                                color: context.colors.light,
                                fontSize: 15,
                                height: 1.5)),
                      ],
                      if (widget.friendActivity != null) ...[
                        const SizedBox(height: 16),
                        ListenableBuilder(
                            listenable: widget.friendActivity!(movie.homeKey),
                            builder: (_, __) {
                              final activity =
                                  widget.friendActivity!(movie.homeKey).value;
                              return HomeFriendActivityFooter(
                                  interactions: activity.data,
                                  loading: activity.loading,
                                  failed: activity.error != null,
                                  onRetry: () =>
                                      widget.onFriendsRetry?.call(movie));
                            }),
                      ],
                      const SizedBox(height: 20),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        if (movie.trailer?.key?.trim().isNotEmpty == true)
                          FilledButton.icon(
                              onPressed: () => widget.onTrailer(movie),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Watch trailer')),
                        OutlinedButton.icon(
                            onPressed:
                                pending ? null : () => widget.onSave(movie),
                            icon: pending
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(saved
                                    ? Icons.bookmark
                                    : Icons.bookmark_outline),
                            label: Text(saved
                                ? 'In your watchlist'
                                : 'Add to watchlist')),
                      ]),
                    ])),
              ]),
            ),
          ),
        SizedBox(height: compact ? 10 : 20),
        LayoutBuilder(builder: (context, constraints) {
          final width = compact
              ? (constraints.maxWidth - 48) / 5
              : ((constraints.maxWidth - 48) / 5).clamp(120.0, 160.0);
          final scale = MediaQuery.textScalerOf(context);
          return SizedBox(
            height: compact
                ? width * 1.22 + scale.scale(32) + 10
                : width * 1.5 + scale.scale(46) + 14,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: railMovies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = railMovies[index];
                return SizedBox(
                    key: ValueKey('trending-poster-${item.homeKey}'),
                    width: width,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Semantics(
                                  selected: item.homeKey == movie.homeKey,
                                  child: _poster(context, item, onTap: () {
                                    setState(() => _selectedId = item.homeKey);
                                    widget.onPageChanged
                                        ?.call(movies.indexOf(item));
                                  }))),
                          const SizedBox(height: 8),
                          Text(item.name,
                              maxLines: 2,
                              overflow: compact
                                  ? TextOverflow.clip
                                  : TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: item.homeKey == movie.homeKey
                                      ? context.colors.primaryText
                                      : context.colors.light,
                                  fontSize: compact ? 11 : 13,
                                  fontWeight: FontWeight.w700)),
                        ]));
              },
            ),
          );
        }),
      ]),
    );
  }

  Widget _compactFeature(BuildContext context, MovieShort movie,
      {required bool hidden, required bool saved, required bool pending}) {
    final year = RegExp(r'\b(?:19|20)\d{2}\b')
        .firstMatch(movie.releaseDate ?? '')
        ?.group(0);
    return Material(
        key: const ValueKey('tablet-trending-feature'),
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 132,
                  height: 180,
                  child: _poster(context, movie,
                      onTap: () => widget.onDetails(movie))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        '${movie.isShow ? 'TV show' : 'Movie'}${year == null ? '' : ' · $year'}',
                        style: TextStyle(
                            color: context.colors.light, fontSize: 12)),
                    TextButton(
                        onPressed: () => widget.onDetails(movie),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            foregroundColor: context.colors.textPrimary),
                        child: Text(movie.name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.15))),
                    if (!hidden && (movie.voteAverage ?? 0) > 0)
                      Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star_rounded,
                                color: context.colors.warning, size: 18),
                            const SizedBox(width: 5),
                            Text(movie.voteAverage!.toStringAsFixed(1),
                                style: TextStyle(
                                    color: context.colors.warning,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ])),
                    if (movie.overview?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                          movie.overview!
                              .trim()
                              .split(RegExp(r'(?<=[.!?])\s+'))
                              .first,
                          style: TextStyle(
                              color: context.colors.light,
                              fontSize: 13,
                              height: 1.4)),
                    ],
                    if (widget.friendActivity != null)
                      ListenableBuilder(
                          listenable: widget.friendActivity!(movie.homeKey),
                          builder: (_, __) {
                            final activity =
                                widget.friendActivity!(movie.homeKey).value;
                            if (activity.data.isEmpty &&
                                !activity.loading &&
                                activity.error == null) {
                              return const SizedBox(height: 8);
                            }
                            return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: HomeFriendActivityFooter(
                                    interactions: activity.data,
                                    loading: activity.loading,
                                    failed: activity.error != null,
                                    onRetry: () =>
                                        widget.onFriendsRetry?.call(movie)));
                          })
                    else
                      const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (movie.trailer?.key?.trim().isNotEmpty == true)
                        FilledButton.icon(
                            onPressed: () => widget.onTrailer(movie),
                            style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                minimumSize: const Size(0, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Watch trailer')),
                      OutlinedButton.icon(
                          onPressed:
                              pending ? null : () => widget.onSave(movie),
                          style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              minimumSize: const Size(0, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          icon: pending
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Icon(
                                  saved
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  size: 18),
                          label: Text(saved
                              ? 'In your watchlist'
                              : 'Add to watchlist')),
                    ]),
                  ])),
            ])));
  }

  Widget _poster(BuildContext context, MovieShort movie,
      {required VoidCallback onTap}) {
    final url = homeHeroImageUrl(movie.poster);
    final placeholder = ColoredBox(
        color: context.colors.surfaceElevated,
        child:
            Icon(Icons.movie_outlined, color: context.colors.medium, size: 36));
    final fallback = HomeTabletLayout.active(context)
        ? SizedBox.expand(child: placeholder)
        : placeholder;
    return Semantics(
        button: true,
        label: 'Select ${movie.name}',
        child: Material(
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: url == null
                    ? fallback
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (_, __) => fallback,
                        errorWidget: (_, __, ___) => fallback))));
  }
}
