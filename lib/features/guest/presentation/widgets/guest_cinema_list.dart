import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/models/home_image_urls.dart';
import 'package:flixie_app/models/movie_short.dart';

/// Cinema stories use the existing region feed and guest-owned actions.
class GuestCinemaList extends StatefulWidget {
  const GuestCinemaList(
      {super.key,
      required this.movies,
      required this.onDetails,
      required this.onSave,
      required this.onTrailer});
  final List<MovieShort> movies;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;

  @override
  State<GuestCinemaList> createState() => _GuestCinemaListState();
}

class _GuestCinemaListState extends State<GuestCinemaList> {
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
                                color: colors.medium))))));
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: InkWell(
                onTap: () => widget.onDetails(movie),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(movie.name,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17))))),
        IconButton(
            tooltip: 'Watchlist',
            onPressed: () => widget.onSave(movie),
            icon: const Icon(Icons.bookmark_add_outlined)),
      ]),
      Wrap(spacing: 8, runSpacing: 4, children: [
        Text('Movie${year == null ? '' : ' · $year'}',
            style: TextStyle(color: colors.medium, fontSize: 12)),
        if ((movie.voteAverage ?? 0) > 0)
          Text('TMDB ${movie.voteAverage!.toStringAsFixed(1)}/10',
              style: TextStyle(color: colors.light, fontSize: 12)),
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
