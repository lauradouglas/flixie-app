class TrendingGroupsResponse {
  final TrendingSummary summary;
  final List<TrendingGroup> groups;

  const TrendingGroupsResponse({
    required this.summary,
    required this.groups,
  });

  factory TrendingGroupsResponse.fromJson(Map<String, dynamic> json) {
    return TrendingGroupsResponse(
      summary: TrendingSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const {},
      ),
      groups: (json['groups'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TrendingGroup.fromJson)
          .toList(),
    );
  }
}

class TrendingSummary {
  final int totalActivities;
  final int moviesDiscussed;
  final int highlyRatedCount;
  final int newGroupsThisWeek;

  const TrendingSummary({
    required this.totalActivities,
    required this.moviesDiscussed,
    required this.highlyRatedCount,
    required this.newGroupsThisWeek,
  });

  factory TrendingSummary.fromJson(Map<String, dynamic> json) {
    return TrendingSummary(
      totalActivities: _toInt(json['totalActivities']) ?? 0,
      moviesDiscussed: _toInt(json['moviesDiscussed']) ?? 0,
      highlyRatedCount: _toInt(json['highlyRatedCount']) ?? 0,
      newGroupsThisWeek: _toInt(json['newGroupsThisWeek']) ?? 0,
    );
  }
}

class TrendingGroup {
  final String id;
  final String name;
  final String? avatarUrl;
  final String initials;
  final int memberCount;
  final double? trendPercent;
  final String trendLabel;
  final int activityCount;
  final List<TrendingMovie> trendingMovies;

  const TrendingGroup({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.initials,
    required this.memberCount,
    this.trendPercent,
    required this.trendLabel,
    required this.activityCount,
    required this.trendingMovies,
  });

  factory TrendingGroup.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? '';
    final initials = (json['initials'] as String?)?.trim();
    return TrendingGroup(
      id: (json['id'] as String?) ?? '',
      name: name,
      avatarUrl: _toImageUrl(_firstValue(json, const [
        'avatarUrl',
        'avatar_url',
        'avatar',
      ])),
      initials: (initials == null || initials.isEmpty)
          ? _buildInitialsFromName(name)
          : initials,
      memberCount: _toInt(json['memberCount']) ?? 0,
      trendPercent: _toDouble(json['trendPercent']),
      trendLabel: (json['trendLabel'] as String?) ?? '',
      activityCount: _toInt(json['activityCount']) ?? 0,
      trendingMovies:
          (_firstValue(json, const ['trendingMovies', 'trending_movies'])
                  as List<dynamic>? ??
              const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(TrendingMovie.fromJson)
              .toList(),
    );
  }
}

class TrendingMovie {
  final String id;
  final int? tmdbId;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final int? year;
  final int activityCount;
  final double? averageRating;

  const TrendingMovie({
    required this.id,
    this.tmdbId,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.year,
    required this.activityCount,
    this.averageRating,
  });

  factory TrendingMovie.fromJson(Map<String, dynamic> json) {
    final nestedMovie = json['movie'] as Map<String, dynamic>?;
    return TrendingMovie(
      id: _toStringOrNull(_firstValue(json, const ['id', 'movieId'])) ?? '',
      tmdbId: _toInt(_firstValue(json, const ['tmdbId', 'tmdb_id', 'movieId'])) ??
          _toInt(_firstValue(nestedMovie, const ['id', 'tmdbId', 'tmdb_id'])),
      title: (_firstValue(
                json,
                const ['title', 'name', 'movieTitle'],
              ) as String?) ??
          (_firstValue(nestedMovie, const ['title', 'name']) as String?) ??
          '',
      posterUrl: _toImageUrl(_firstValue(json, const [
            'posterUrl',
            'poster',
            'posterPath',
            'poster_path',
            'moviePosterPath',
          ])) ??
          _toImageUrl(_firstValue(nestedMovie, const [
            'posterUrl',
            'poster',
            'posterPath',
            'poster_path',
          ])),
      backdropUrl: _toImageUrl(_firstValue(json, const [
            'backdropUrl',
            'backdropPath',
            'backdrop_path',
          ])) ??
          _toImageUrl(_firstValue(nestedMovie, const [
            'backdropUrl',
            'backdropPath',
            'backdrop_path',
          ])),
      year: _toInt(json['year']),
      activityCount: _toInt(_firstValue(json, const ['activityCount', 'activity_count'])) ?? 0,
      averageRating: _toDouble(_firstValue(json, const ['averageRating', 'average_rating'])),
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _toStringOrNull(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

dynamic _firstValue(Map<String, dynamic>? json, List<String> keys) {
  if (json == null) return null;
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

String? _toImageUrl(dynamic value) {
  final raw = _toStringOrNull(value);
  if (raw == null) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  if (raw.startsWith('/')) return 'https://image.tmdb.org/t/p/w342$raw';
  return 'https://image.tmdb.org/t/p/w342/$raw';
}

String _buildInitialsFromName(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return 'G';
  if (words.length == 1) return words.first[0].toUpperCase();
  final parts = words.take(2).toList(growable: false);
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
