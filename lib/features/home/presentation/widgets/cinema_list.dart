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
      this.savedIds = const {},
      this.pendingIds = const {}});
  final Set<int> savedIds, pendingIds;
  final List<MovieShort> movies;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;

  @override
  State<CinemaList> createState() => _CinemaListState();
}

class _CinemaListState extends State<CinemaList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final movie
            in widget.movies.take(_expanded ? widget.movies.length : 3))
          _row(context, movie),
        if (widget.movies.length > 3)
          TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded
                  ? 'Show fewer cinema releases'
                  : 'Show more cinema releases')),
      ]);

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
            Text('Movie${year == null ? '' : ' · $year'}',
                style: TextStyle(color: colors.medium, fontSize: 12)),
            if ((movie.voteAverage ?? 0) > 0)
              Text('TMDB ${movie.voteAverage!.toStringAsFixed(1)}/10',
                  style: TextStyle(color: colors.light, fontSize: 12)),
          ]),
        ])),
        IconButton(
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
                    : Icons.bookmark_add_outlined)),
      ]),
      if (movie.tagline?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(movie.tagline!,
            style: TextStyle(color: colors.light, fontSize: 13, height: 1.4)),
      ],
      if (movie.overview?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(movie.overview!.trim().split(RegExp(r'(?<=[.!?])\s+')).first,
            style: TextStyle(color: colors.light, fontSize: 13, height: 1.4)),
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
