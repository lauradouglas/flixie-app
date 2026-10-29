import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'home_tablet_layout.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/models/home_image_urls.dart';
import 'package:flixie_app/models/movie_short.dart';

/// Cinema stories share region data and caller-owned actions across Home states.
class CinemaList extends StatefulWidget {
  const CinemaList(
      {super.key,
      required this.movies,
      required this.onDetails,
      required this.onSave,
      required this.onTrailer,
      this.showAll = false,
      this.savedIds = const {},
      this.pendingIds = const {}});
  final bool showAll;
  final Set<int> savedIds, pendingIds;
  final List<MovieShort> movies;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;

  @override
  State<CinemaList> createState() => _CinemaListState();
}

class _CinemaListState extends State<CinemaList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies.take(_expanded ? widget.movies.length : 3);
    final tablet = HomeTabletLayout.active(context);
    return Column(children: [
      if (tablet && widget.showAll)
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth >= 1080
              ? 3
              : box.maxWidth >= 720
                  ? 2
                  : 1;
          final width = (box.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final movie in widget.movies)
              SizedBox(width: width, child: _tabletCard(context, movie)),
          ]);
        })
      else if (tablet)
        LayoutBuilder(builder: (context, box) {
          final width = HomeTabletLayout.portrait(context)
              ? ((box.maxWidth - 12) / 1.85).clamp(400.0, 520.0)
              : ((box.maxWidth - 24) / (box.maxWidth >= 720 ? 3.2 : 2.2))
                  .clamp(340.0, 420.0);
          return SingleChildScrollView(
              key: const ValueKey('tablet-cinema-rail'),
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    for (var i = 0; i < widget.movies.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      SizedBox(
                          width: width,
                          child: _tabletCard(context, widget.movies[i])),
                    ],
                  ])));
        })
      else
        for (final movie in movies) _row(context, movie),
      if (!tablet && widget.movies.length > 3)
        TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded
                ? 'Show fewer cinema releases'
                : 'Show more cinema releases')),
    ]);
  }

  Widget _tabletCard(BuildContext context, MovieShort movie) {
    final url = homeHeroImageUrl(movie.poster);
    final saved = widget.savedIds.contains(movie.homeKey);
    final pending = widget.pendingIds.contains(movie.homeKey);
    final year = RegExp(r'\b(?:19|20)\d{2}\b')
        .firstMatch(movie.releaseDate ?? '')
        ?.group(0);
    final height = 220 + 44 * (MediaQuery.textScalerOf(context).scale(1) - 1);
    final synopsis =
        movie.overview?.trim().split(RegExp(r'(?<=[.!?])\s+')).firstOrNull;
    return Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.colors.tabBarBorder)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: () => widget.onDetails(movie),
            child: SizedBox(
                height: height,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: SizedBox(
                              width: (height - 12) * 2 / 3,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: url == null
                                      ? const Icon(Icons.movie_outlined)
                                      : CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.contain,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(
                                                  Icons.movie_outlined))))),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: SingleChildScrollView(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                          Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                      Text(movie.name,
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800)),
                                                      const SizedBox(height: 4),
                                                      Wrap(
                                                          spacing: 10,
                                                          runSpacing: 4,
                                                          crossAxisAlignment:
                                                              WrapCrossAlignment
                                                                  .center,
                                                          children: [
                                                            if (year != null)
                                                              Text(year,
                                                                  style: TextStyle(
                                                                      color: context
                                                                          .colors
                                                                          .light,
                                                                      fontSize:
                                                                          12)),
                                                            if (!hideMovieRatings(
                                                                    context,
                                                                    movie.id) &&
                                                                (movie.voteAverage ??
                                                                        0) >
                                                                    0)
                                                              Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Icon(
                                                                        Icons
                                                                            .star_rounded,
                                                                        color: context
                                                                            .colors
                                                                            .warning,
                                                                        size:
                                                                            20),
                                                                    const SizedBox(
                                                                        width:
                                                                            4),
                                                                    Text(
                                                                        movie
                                                                            .voteAverage!
                                                                            .toStringAsFixed(
                                                                                1),
                                                                        style: TextStyle(
                                                                            color: context
                                                                                .colors.warning,
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.w800)),
                                                                  ]),
                                                          ]),
                                                    ])),
                                                IconButton(
                                                    alignment:
                                                        Alignment.topRight,
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(
                                                            minWidth: 44,
                                                            minHeight: 44),
                                                    color:
                                                        context.colors.warning,
                                                    tooltip: saved
                                                        ? 'Remove from watchlist'
                                                        : 'Watchlist',
                                                    onPressed: pending
                                                        ? null
                                                        : () => widget
                                                            .onSave(movie),
                                                    icon: pending
                                                        ? const SizedBox.square(
                                                            dimension: 18,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2))
                                                        : Icon(
                                                            saved
                                                                ? Icons.bookmark
                                                                : Icons
                                                                    .bookmark_outline,
                                                            size: 20)),
                                              ]),
                                          if (synopsis?.isNotEmpty == true) ...[
                                            const SizedBox(height: 12),
                                            Text(synopsis!,
                                                style: TextStyle(
                                                    color: context.colors.light,
                                                    fontSize: 12,
                                                    height: 1.4)),
                                          ],
                                        ]))),
                                    const SizedBox(height: 8),
                                    Wrap(
                                        spacing: 10,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          if (movie.trailer?.key
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true)
                                            TextButton.icon(
                                                onPressed: () =>
                                                    widget.onTrailer(movie),
                                                style: TextButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4)),
                                                icon: const Icon(
                                                    Icons.play_circle_outline,
                                                    size: 20),
                                                label: const Text('Trailer')),
                                        ]),
                                  ]))),
                    ]))));
  }

  Widget _row(BuildContext context, MovieShort movie) {
    final colors = context.colors;
    final year = RegExp(r'\b(?:19|20)\d{2}\b')
        .firstMatch(movie.releaseDate ?? '')
        ?.group(0);
    final url = homeHeroImageUrl(movie.poster);
    final poster = Tooltip(
        message: 'Details',
        child: InkWell(
            onTap: () => widget.onDetails(movie),
            child: Semantics(
                label: '${movie.name} poster',
                image: true,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                        width: 82,
                        height: 123,
                        child: url == null
                            ? ColoredBox(
                                color: colors.surface,
                                child: Icon(Icons.movie_outlined,
                                    color: colors.medium))
                            : CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => Icon(
                                    Icons.movie_outlined,
                                    color: colors.medium)))))));
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
              onTap: () => widget.onDetails(movie),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(movie.name,
                    style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.2)),
              )),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (year != null)
              Text(year, style: TextStyle(color: colors.medium, fontSize: 12)),
            if ((movie.voteAverage ?? 0) > 0)
              Semantics(
                  label:
                      'Rating ${movie.voteAverage!.toStringAsFixed(1)} out of 10',
                  child: ExcludeSemantics(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 15, color: colors.warning),
                    const SizedBox(width: 3),
                    Text(movie.voteAverage!.toStringAsFixed(1),
                        style: TextStyle(
                            color: colors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]))),
          ]),
        ])),
        IconButton(
            color: colors.warning,
            alignment: Alignment.topRight,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            tooltip: widget.savedIds.contains(movie.homeKey)
                ? 'Remove from watchlist'
                : 'Watchlist',
            onPressed: widget.pendingIds.contains(movie.homeKey)
                ? null
                : () => widget.onSave(movie),
            icon: widget.pendingIds.contains(movie.homeKey)
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(widget.savedIds.contains(movie.homeKey)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded)),
      ]),
      if (movie.tagline?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(movie.tagline!,
            style: TextStyle(color: colors.light, fontSize: 12, height: 1.4)),
      ],
      if (movie.overview?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(movie.overview!.trim().split(RegExp(r'(?<=[.!?])\s+')).first,
            style: TextStyle(color: colors.light, fontSize: 12, height: 1.4)),
      ],
      if (movie.trailer?.key?.trim().isNotEmpty == true)
        TextButton.icon(
            onPressed: () => widget.onTrailer(movie),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Trailer')),
    ]);
    return LayoutBuilder(builder: (context, box) {
      final stack =
          box.maxWidth < 340 && MediaQuery.textScalerOf(context).scale(1) > 1.4;
      return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: colors.primary.withValues(alpha: .15)))),
            child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: stack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [poster, const SizedBox(height: 8), details])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            poster,
                            const SizedBox(width: 14),
                            Expanded(child: details)
                          ])),
          ));
    });
  }
}

/// Reserve the same poster-left geometry while the cinema feed resolves.
class CinemaListSkeleton extends StatelessWidget {
  const CinemaListSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Loading cinema releases',
      child: ExcludeSemantics(
          child: Column(children: [
        for (var i = 0; i < 3; i++)
          const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(width: 82, height: 123, borderRadius: 6),
                SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      SkeletonBox(height: 18),
                      SizedBox(height: 8),
                      FractionallySizedBox(
                          widthFactor: .5, child: SkeletonBox(height: 12)),
                      SizedBox(height: 14),
                      SkeletonBox(height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12)
                    ])),
              ])),
      ])));
}
