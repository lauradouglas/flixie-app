import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_watch_request.dart';

/// Shows every proposed film before a member decides whether to join.
class WatchPlanMovieOptions extends StatelessWidget {
  const WatchPlanMovieOptions({super.key, required this.candidates});
  final List<GroupWatchPlanCandidate> candidates;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final columns = MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? 1
            : (box.maxWidth / 140).floor().clamp(1, 3);
        final width = (box.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 16, children: [
          for (final candidate in candidates)
            SizedBox(
                width: width,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: candidate.posterPath?.isNotEmpty == true
                                  ? CachedNetworkImage(
                                      imageUrl: candidate.posterPath!
                                              .startsWith('http')
                                          ? candidate.posterPath!
                                          : 'https://image.tmdb.org/t/p/w342${candidate.posterPath}',
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => _fallback(),
                                      errorWidget: (_, __, ___) => _fallback())
                                  : _fallback())),
                      const SizedBox(height: 8),
                      Text(candidate.title ?? 'Movie option',
                          style: const TextStyle(
                              color: FlixieColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.35)),
                    ])),
        ]);
      });

  Widget _fallback() => Container(
      color: FlixieColors.tabBarBackgroundFocused,
      child: const Center(
          child:
              Icon(Icons.movie_outlined, color: FlixieColors.light, size: 32)));
}
