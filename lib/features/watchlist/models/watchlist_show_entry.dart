import 'package:flixie_app/models/show.dart';

class WatchlistShowEntry {
  const WatchlistShowEntry({
    required this.showId,
    required this.title,
    required this.removed,
    required this.watched,
    this.posterPath,
    this.firstAirDate,
    this.status,
    this.numberOfEpisodes,
    this.numberOfSeasons,
    this.voteAverage,
    this.runtime,
    this.genres = const [],
    this.createdAt,
  });

  final int showId;
  final String title;
  final bool removed;
  final bool watched;
  final String? posterPath;
  final String? firstAirDate;
  final String? status;
  final int? numberOfEpisodes;
  final int? numberOfSeasons;
  final double? voteAverage;
  final int? runtime;
  final List<String> genres;
  final String? createdAt;

  bool get needsDetails =>
      title == 'TV show' ||
      title.trim().isEmpty ||
      posterPath == null ||
      firstAirDate == null ||
      numberOfSeasons == null ||
      runtime == null ||
      genres.isEmpty;

  WatchlistShowEntry withShow(TvShow show) => WatchlistShowEntry.fromJson({
        'showId': showId,
        'removed': removed,
        'watched': watched,
        'createdAt': createdAt,
        'show': {
          ...show.toJson(),
          if (show.genres.isEmpty) 'genres': genres,
          if (show.episodeRuntime == null) 'episodeRuntime': runtime,
        },
      });

  factory WatchlistShowEntry.fromJson(Map<String, dynamic> json) {
    final show = json['show'] is Map
        ? Map<String, dynamic>.from(json['show'] as Map)
        : const <String, dynamic>{};
    return WatchlistShowEntry(
      showId: watchlistInt(json['showId']) ?? watchlistInt(show['id']) ?? 0,
      title: (show['title'] ?? show['name'] ?? 'TV show').toString(),
      removed: json['removed'] == true,
      watched: json['watched'] == true,
      posterPath: (show['posterPath'] ?? show['poster_path'])?.toString(),
      firstAirDate: (show['firstAirDate'] ??
              show['first_air_date'] ??
              show['releaseDate'])
          ?.toString(),
      status: show['status']?.toString(),
      numberOfEpisodes: watchlistInt(show['numberOfEpisodes']),
      numberOfSeasons:
          watchlistInt(show['numberOfSeasons'] ?? show['number_of_seasons']),
      voteAverage: double.tryParse('${show['voteAverage'] ?? ''}'),
      runtime: TvShow.fromJson(show).episodeRuntime,
      genres: (show['genres'] as List? ?? const [])
          .map((g) => g is Map ? '${g['name'] ?? ''}' : '$g')
          .where((g) => g.isNotEmpty)
          .toList(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

int? watchlistInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
