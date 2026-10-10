import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../models/pick_for_us_result.dart';

class PickResultCard extends StatelessWidget {
  const PickResultCard({super.key, required this.pick, required this.solo});
  final PickForUsResult pick;
  final bool solo;
  @override
  Widget build(BuildContext context) {
    Widget note(String text) =>
        Text(text, style: TextStyle(color: context.colors.medium, height: 1.5));
    Widget heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
        child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleLarge)));
    final movie = pick.movie;
    final poster = movie.poster;
    final image = poster == null
        ? null
        : poster.startsWith('http')
            ? poster
            : 'https://image.tmdb.org/t/p/w342$poster';
    final artwork = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image == null
            ? Container(
                width: 104,
                height: 156,
                color: context.colors.surface,
                child: const Icon(Icons.movie_outlined, size: 40))
            : CachedNetworkImage(
                imageUrl: image,
                width: 104,
                height: 156,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                    width: 104,
                    height: 156,
                    color: context.colors.surface,
                    child: const Icon(Icons.movie_outlined, size: 40))));
    final title =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(movie.name,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      note('${pick.runtime} min'),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 360 &&
                  MediaQuery.textScalerOf(context).scale(16) > 22
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [artwork, const SizedBox(height: 16), title])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  artwork,
                  const SizedBox(width: 20),
                  Expanded(child: title)
                ])),
      if (movie.overview?.isNotEmpty == true) ...[
        const SizedBox(height: 20),
        Text(movie.overview!, style: const TextStyle(height: 1.5))
      ],
      if (movie.recommendationReasons.isNotEmpty) ...[
        heading('Why this fits'),
        for (final reason in movie.recommendationReasons)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check, size: 20, color: context.colors.secondary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(reason, style: const TextStyle(height: 1.5))),
              ])),
      ],
      const SizedBox(height: 16),
      if (!solo)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: () => context.push('/movies/${movie.id}'),
                child: const Text('View movie details'))),
    ]);
  }
}
