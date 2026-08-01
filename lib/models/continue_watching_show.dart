class ContinueWatchingShow {
  const ContinueWatchingShow({
    required this.showId,
    required this.name,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    required this.completionPercent,
    this.posterPath,
    this.backdropPath,
    this.lastWatchedEpisode,
  });

  final int showId;
  final String name;
  final String? posterPath;
  final String? backdropPath;
  final int watchedEpisodes;
  final int totalEpisodes;
  final int completionPercent;
  final ContinueWatchingEpisode? lastWatchedEpisode;

  factory ContinueWatchingShow.fromJson(Map<String, dynamic> json) {
    final episode = json['lastWatchedEpisode'];
    return ContinueWatchingShow(
      showId: (json['showId'] as num).toInt(),
      name: json['name'] as String? ?? 'Unknown Show',
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      watchedEpisodes: (json['watchedEpisodes'] as num?)?.toInt() ?? 0,
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? 0,
      completionPercent: (json['completionPercent'] as num?)?.toInt() ?? 0,
      lastWatchedEpisode: episode is Map<String, dynamic>
          ? ContinueWatchingEpisode.fromJson(episode)
          : null,
    );
  }
}

class ContinueWatchingEpisode {
  const ContinueWatchingEpisode({
    required this.seasonNumber,
    required this.episodeNumber,
    this.title,
  });

  final int seasonNumber;
  final int episodeNumber;
  final String? title;

  factory ContinueWatchingEpisode.fromJson(Map<String, dynamic> json) {
    return ContinueWatchingEpisode(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
    );
  }
}
