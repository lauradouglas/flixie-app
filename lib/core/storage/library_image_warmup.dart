import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flixie_app/models/user.dart';

/// Only the first visible library rows, never the entire collection.
List<String> libraryPosterWarmupUrls(User user) {
  final paths = <String>{};
  for (final item in user.movieWatchlist ?? []) {
    if (item.removed != true && item.movie?.posterPath != null) {
      paths.add(item.movie!.posterPath!);
    }
    if (paths.length >= 4) break;
  }
  for (final item in (user.showWatchlist ?? []).whereType<Map>()) {
    final show = item['show'] as Map?;
    final path = show?['posterPath'] ?? show?['poster_path'];
    if (item['removed'] != true && path is String && path.isNotEmpty) {
      paths.add(path);
    }
    if (paths.length >= 6) break;
  }
  return paths
      .take(6)
      .map((path) => path.startsWith('http')
          ? path
          : 'https://image.tmdb.org/t/p/w342$path')
      .toList();
}

/// Watchlist rows are 68 logical pixels wide; never decode beyond the w342 source.
int watchlistPosterDecodeWidth(double devicePixelRatio) =>
    (68 * devicePixelRatio).ceil().clamp(1, 342);

/// Must match CachedNetworkImage's memCacheWidth wrapper in WatchlistMovieRow.
/// Keep the disk URL unchanged so larger displays can reuse the source file.
ImageProvider libraryPosterWarmupProvider(
        String url, double devicePixelRatio) =>
    ResizeImage.resizeIfNeeded(watchlistPosterDecodeWidth(devicePixelRatio),
        null, CachedNetworkImageProvider(url));
