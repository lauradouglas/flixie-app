import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/models/user.dart';

/// Matches the watchlist's default (recently saved) order, including TV shows.
List<Map<String, dynamic>> watchlistWidgetItems(User? user) {
  final items = <Map<String, dynamic>>[
    for (final item in user?.movieWatchlist ?? [])
      if (item.removed != true)
        {
          'id': 'movie-${item.movieId}',
          'title': item.movie?.title ?? 'Movie',
          'poster': item.movie?.posterPath,
          'added': item.createdAt
        },
    for (final raw in user?.showWatchlist ?? [])
      if (raw is Map && raw['removed'] != true && raw['watched'] != true)
        {
          'id': 'show-${raw['showId']}',
          'title': raw['show']?['title'] ?? raw['show']?['name'] ?? 'TV show',
          'poster': raw['show']?['posterPath'] ?? raw['show']?['poster_path'],
          'added': raw['createdAt']
        },
  ];
  DateTime added(Map<String, dynamic> item) =>
      DateTime.tryParse(item['added']?.toString() ?? '') ?? DateTime(1970);
  items.sort((a, b) {
    final recent = added(b).compareTo(added(a));
    return recent != 0 ? recent : '${a['id']}'.compareTo('${b['id']}');
  });
  final seen = <String>{};
  return items
      .where((item) => seen.add(item['id'] as String))
      .take(4)
      .map((item) => Map<String, dynamic>.from(item)..remove('added'))
      .toList();
}

class WatchlistWidgetSync {
  static const channel = MethodChannel('flixie/watchlist_widget');
  String? _last;

  void sync(User? user) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    final payload = {'account': user?.id, 'items': watchlistWidgetItems(user)};
    final signature = jsonEncode(payload);
    if (_last == signature) return;
    _last = signature;
    channel.invokeMethod<void>('sync', payload).catchError((Object error) {
      // A missing extension or temporary platform failure must not break auth.
      if (_last == signature) _last = null;
      debugPrint('Watchlist widget could not refresh: $error');
    });
  }
}
