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
    final movies = widget.movies.take(8).toList(growable: false);
    if (movies.isEmpty) return const SizedBox.shrink();
    final movie =
        movies.where((m) => m.id == _selectedId).firstOrNull ?? movies.first;
    final hidden = context
        .select<MovieRatingPrivacy?, bool>((p) => p?.hides(movie.id) ?? false);
    final saved = widget.savedIds.contains(movie.id);
    final pending = widget.pendingIds.contains(movie.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 160,
                  child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: _poster(context, movie,
                          onTap: () => widget.onDetails(movie)))),
              const SizedBox(width: 24),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      Text(movie.overview!,
                          style: TextStyle(
                              color: context.colors.light,
                              fontSize: 15,
                              height: 1.5)),
                    ],
                    if (widget.friendActivity != null) ...[
                      const SizedBox(height: 16),
                      ListenableBuilder(
                          listenable: widget.friendActivity!(movie.id),
                          builder: (_, __) {
                            final activity =
                                widget.friendActivity!(movie.id).value;
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
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
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final width = ((constraints.maxWidth - 48) / 5).clamp(120.0, 160.0);
          final scale = MediaQuery.textScalerOf(context);
          return SizedBox(
            height: width * 1.5 + scale.scale(46) + 14,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = movies[index];
                return SizedBox(
                    key: ValueKey('trending-poster-${item.id}'),
                    width: width,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Semantics(
                                  selected: item.id == movie.id,
                                  child: _poster(context, item, onTap: () {
                                    setState(() => _selectedId = item.id);
                                    widget.onPageChanged?.call(index);
                                  }))),
                          const SizedBox(height: 8),
                          Text(item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: item.id == movie.id
                                      ? context.colors.primaryText
                                      : context.colors.light,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ]));
              },
            ),
          );
        }),
      ]),
    );
  }

  Widget _poster(BuildContext context, MovieShort movie,
      {required VoidCallback onTap}) {
    final url = homeHeroImageUrl(movie.poster);
    final fallback = ColoredBox(
        color: context.colors.surfaceElevated,
        child:
            Icon(Icons.movie_outlined, color: context.colors.medium, size: 36));
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
