import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Restrict poll artwork to bounded TMDB derivatives, including full TMDB URLs.
String? pollPosterUrl(String? path, {bool winner = false}) {
  if (path == null || path.trim().isEmpty) return null;
  final uri = Uri.tryParse(path.trim());
  if (uri == null) return null;
  String? file;
  if (!uri.hasScheme && path.startsWith('/') && !path.startsWith('//')) {
    file = path.substring(1);
  } else if (uri.scheme == 'https' && uri.host == 'image.tmdb.org') {
    final parts = uri.pathSegments;
    if (parts.length == 4 && parts[0] == 't' && parts[1] == 'p') {
      file = parts[3];
    }
  }
  if (file == null ||
      !RegExp(r'^[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp)$').hasMatch(file)) {
    return null;
  }
  return 'https://image.tmdb.org/t/p/${winner ? 'w500' : 'w185'}/$file';
}

class CommunityPollPoster extends StatelessWidget {
  const CommunityPollPoster(
      {super.key, required this.path, this.winner = false});
  final String? path;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final width = winner ? 88.0 : 42.0;
    final url = pollPosterUrl(path, winner: winner);
    final fallback = ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Center(
            child: Icon(Icons.movie_outlined,
                size: winner ? 28 : 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer)));
    return ExcludeSemantics(
        child: ClipRRect(
      borderRadius: BorderRadius.circular(winner ? 10 : 7),
      child: SizedBox(
          width: width,
          height: width * 1.5,
          child: url == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url,
                  memCacheWidth:
                      (width * MediaQuery.devicePixelRatioOf(context))
                          .ceil()
                          .clamp(1, winner ? 500 : 185),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => fallback,
                  errorWidget: (_, __, ___) => fallback,
                )),
    ));
  }
}

class CommunityPollOutcome extends StatelessWidget {
  const CommunityPollOutcome(
      {super.key, required this.options, required this.total});
  final List<Map<String, dynamic>> options;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0 || options.isEmpty) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('No winner this time.'));
    }
    final highest =
        options.map((o) => o['votes'] as int).reduce((a, b) => a > b ? a : b);
    final leaders = options.where((o) => o['votes'] == highest).toList();
    final tied = leaders.length > 1;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(tied ? Icons.people_outline : Icons.emoji_events_outlined,
                color: scheme.secondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(tied ? 'Joint winners' : 'Community winner',
                    style: TextStyle(
                        color: scheme.secondary, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          for (final leader in leaders)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommunityPollPoster(
                          path: leader['posterPath'] as String?, winner: true),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(leader['title'] ?? 'Unavailable title',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(
                                '${(highest / total * 100).round()}% · $highest of $total votes',
                                style:
                                    TextStyle(color: scheme.onSurfaceVariant)),
                          ])),
                    ])),
        ]));
  }
}
