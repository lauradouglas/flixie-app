import 'package:flixie_app/models/watch_provider.dart';

class TvShow {
  final int id;
  final String name;
  final String? firstAirDate;
  final String? lastAirDate;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? popularity;
  final double? voteAverage;
  final double? tmdbRating;
  final double? imdbRating;
  final String? imdbRatingLabel;
  final String? rottenTomatoRatingLabel;
  final String? metascoreRatingLabel;
  final double? flixieScore;
  final double? friendRating;
  final int? friendRecommendPercent;
  final int? voteCount;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final String? tagline;
  final String? status;
  final String? originalLanguage;
  final List<String> originCountry;
  final List<String> genres;
  final List<String> networks;
  final List<String> createdBy;
  final List<TvSeason> seasons;
  final List<TvEpisode> episodes;
  final List<TvShowCredit> cast;
  final List<TvShowCredit> crew;
  final List<TvShow> similarShows;
  final List<TvShowFriendActivity> friendActivity;
  final TvShowFriendSummary? friendSummary;
  final List<WatchProvider> watchProviders;
  final int? watchedEpisodeCount;

  const TvShow({
    required this.id,
    required this.name,
    this.firstAirDate,
    this.lastAirDate,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.popularity,
    this.voteAverage,
    this.tmdbRating,
    this.imdbRating,
    this.imdbRatingLabel,
    this.rottenTomatoRatingLabel,
    this.metascoreRatingLabel,
    this.flixieScore,
    this.friendRating,
    this.friendRecommendPercent,
    this.voteCount,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.tagline,
    this.status,
    this.originalLanguage,
    this.originCountry = const [],
    this.genres = const [],
    this.networks = const [],
    this.createdBy = const [],
    this.seasons = const [],
    this.episodes = const [],
    this.cast = const [],
    this.crew = const [],
    this.similarShows = const [],
    this.friendActivity = const [],
    this.friendSummary,
    this.watchProviders = const [],
    this.watchedEpisodeCount,
  });

  factory TvShow.fromJson(Map<String, dynamic> json) {
    final progressByEpisodeId = _episodeProgressByEpisodeId(
      json['progress'] ??
          json['episodeProgress'] ??
          json['watchedEpisodes'] ??
          json['userState']?['watchProgress']?['progress'],
    );
    final seasons = _mapList(
      json['seasons'],
      (seasonJson) => TvSeason.fromJson(
        seasonJson,
        progressByEpisodeId: progressByEpisodeId,
      ),
    );
    final episodes = _mapList(
      json['episodes'],
      (episodeJson) => TvEpisode.fromJson(
        episodeJson,
        progress: progressByEpisodeId[_intValue(episodeJson['id'])],
      ),
    );

    return TvShow(
      id: _intValue(json['id']) ?? 0,
      name: _stringValue(json['name'] ?? json['title']) ?? 'Unknown Show',
      firstAirDate:
          _stringValue(json['firstAirDate'] ?? json['first_air_date']),
      lastAirDate: _stringValue(json['lastAirDate'] ?? json['last_air_date']),
      overview: _stringValue(json['overview']),
      posterPath: _stringValue(json['posterPath'] ?? json['poster_path']),
      backdropPath: _stringValue(json['backdropPath'] ?? json['backdrop_path']),
      popularity: _doubleValue(json['popularity']),
      voteAverage: _doubleValue(json['voteAverage'] ?? json['vote_average']),
      tmdbRating: _doubleValue(json['tmdbRating'] ?? json['tmdbVoteAverage']),
      imdbRating: _ratingValue(
        json['imdbRating'] ?? json['ratings']?['imdbRating'],
      ),
      imdbRatingLabel:
          _stringValue(json['imdbRating'] ?? json['ratings']?['imdbRating']),
      rottenTomatoRatingLabel: _stringValue(
        json['rottenTomatoRating'] ?? json['ratings']?['rottenTomatoRating'],
      ),
      metascoreRatingLabel: _stringValue(
        json['metascoreRating'] ?? json['ratings']?['metascoreRating'],
      ),
      flixieScore: _doubleValue(json['flixieScore'] ?? json['userScore']),
      friendRating: _doubleValue(json['friendRating'] ?? json['friendsRating']),
      friendRecommendPercent: _intValue(
        json['friendRecommendPercent'] ?? json['friendsRecommendPercent'],
      ),
      voteCount: _intValue(json['voteCount'] ?? json['vote_count']),
      numberOfSeasons:
          _intValue(json['numberOfSeasons'] ?? json['seasonCount']),
      numberOfEpisodes:
          _intValue(json['numberOfEpisodes'] ?? json['episodeCount']),
      tagline: _stringValue(json['tagline']),
      status: _stringValue(json['status']),
      originalLanguage: _stringValue(
        json['originalLanguage'] ?? json['original_language'],
      ),
      originCountry: _stringList(json['originCountry'] ?? json['countries']),
      genres: _nameList(json['genres']),
      networks: _nameList(json['networks'] ?? json['network']),
      createdBy: _creatorNames(
        json['creator'] ?? json['createdBy'] ?? json['created_by'],
      ),
      seasons: seasons,
      episodes: episodes,
      cast: _mapList(
          json['cast'] ?? json['credits']?['cast'], TvShowCredit.fromJson),
      crew: _mapList(
          json['crew'] ?? json['credits']?['crew'], TvShowCredit.fromJson),
      similarShows: _mapList(
        json['similarShows'] ?? json['similar'] ?? json['recommendations'],
        TvShow.fromJson,
      ),
      friendActivity: _mapList(
        json['friendActivity'] ?? json['friendsActivity'],
        TvShowFriendActivity.fromJson,
      ),
      friendSummary: json['friendSummary'] is Map<String, dynamic>
          ? TvShowFriendSummary.fromJson(
              json['friendSummary'] as Map<String, dynamic>,
            )
          : null,
      watchProviders: _mapList(
        json['watchProviders'] ?? json['providers'],
        WatchProvider.fromJson,
      ),
      watchedEpisodeCount: _intValue(
        json['watchedEpisodeCount'] ??
            json['userState']?['watchProgress']?['watchedEpisodeCount'] ??
            json['userState']?['watchProgress']?['episodesWatched'] ??
            json['userState']?['watchProgress']?['watchedCount'],
      ),
    );
  }

  List<TvEpisode> episodesForSeason(int seasonNumber) {
    final fromFlatList =
        episodes.where((episode) => episode.seasonNumber == seasonNumber);
    if (fromFlatList.isNotEmpty) return fromFlatList.toList();
    return seasons
        .where((season) => season.seasonNumber == seasonNumber)
        .expand((season) => season.episodes)
        .toList();
  }

  int get resolvedEpisodeCount {
    if ((numberOfEpisodes ?? 0) > 0) return numberOfEpisodes!;
    if (episodes.isNotEmpty) return episodes.length;
    return seasons.fold<int>(0, (total, season) {
      if (season.episodes.isNotEmpty) return total + season.episodes.length;
      return total + (season.episodeCount ?? 0);
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'firstAirDate': firstAirDate,
      'lastAirDate': lastAirDate,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'popularity': popularity,
      'voteAverage': voteAverage,
      'voteCount': voteCount,
      'numberOfSeasons': numberOfSeasons,
      'numberOfEpisodes': numberOfEpisodes,
      'tagline': tagline,
      'status': status,
    };
  }
}

class TvSeason {
  final int id;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? posterPath;
  final String? airDate;
  final int? episodeCount;
  final int watchedEpisodeCount;
  final List<TvEpisode> episodes;

  const TvSeason({
    required this.id,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.posterPath,
    this.airDate,
    this.episodeCount,
    this.watchedEpisodeCount = 0,
    this.episodes = const [],
  });

  factory TvSeason.fromJson(
    Map<String, dynamic> json, {
    Map<int, Map<String, dynamic>> progressByEpisodeId = const {},
  }) {
    final seasonNumber =
        _intValue(json['seasonNumber'] ?? json['season_number']) ?? 0;
    final localProgressByEpisodeId = {
      ...progressByEpisodeId,
      ..._episodeProgressByEpisodeId(
        json['progress'] ?? json['userProgress']?['progress'],
      ),
    };
    final episodes = _mapList(
      json['episodes'],
      (episodeJson) => TvEpisode.fromJson(
        episodeJson,
        progress: localProgressByEpisodeId[_intValue(episodeJson['id'])],
      ),
    );
    final watchedCountFromEpisodes =
        episodes.where((episode) => episode.watched).length;
    final resolvedEpisodeCount = _intValue(
          json['episodeCount'] ?? json['userProgress']?['episodeCount'],
        ) ??
        (episodes.isNotEmpty ? episodes.length : null);
    final seasonWatched = _boolValue(json['userProgress']?['watched']);
    return TvSeason(
      id: _intValue(json['id']) ?? seasonNumber,
      seasonNumber: seasonNumber,
      name: _stringValue(json['name']) ?? 'Season $seasonNumber',
      overview: _stringValue(json['overview']),
      posterPath: _stringValue(json['posterPath'] ?? json['poster_path']),
      airDate: _stringValue(json['airDate'] ?? json['air_date']),
      episodeCount: resolvedEpisodeCount,
      watchedEpisodeCount: _intValue(
            json['watchedEpisodeCount'] ??
                json['userProgress']?['watchedEpisodeCount'] ??
                json['userProgress']?['episodesWatched'] ??
                json['userProgress']?['watchedCount'],
          ) ??
          (seasonWatched == true && resolvedEpisodeCount != null
              ? resolvedEpisodeCount
              : watchedCountFromEpisodes),
      episodes: episodes,
    );
  }

  int get resolvedEpisodeCount =>
      episodeCount ?? (episodes.isNotEmpty ? episodes.length : 0);
}

class TvEpisode {
  final int id;
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final String? overview;
  final String? stillPath;
  final String? airDate;
  final int? runtime;
  final double? voteAverage;
  final bool watched;
  final double? userRating;

  const TvEpisode({
    required this.id,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.runtime,
    this.voteAverage,
    this.watched = false,
    this.userRating,
  });

  factory TvEpisode.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? progress,
  }) {
    final userState = json['userState'] is Map<String, dynamic>
        ? json['userState'] as Map<String, dynamic>
        : null;
    final effectiveProgress = progress ?? userState;
    return TvEpisode(
      id: _intValue(json['id']) ?? 0,
      seasonNumber:
          _intValue(json['seasonNumber'] ?? json['season_number']) ?? 0,
      episodeNumber:
          _intValue(json['episodeNumber'] ?? json['episode_number']) ?? 0,
      name: _stringValue(json['name'] ?? json['title']) ?? 'Episode',
      overview: _stringValue(json['overview']),
      stillPath: _stringValue(json['stillPath'] ?? json['still_path']),
      airDate: _stringValue(json['airDate'] ?? json['air_date']),
      runtime: _intValue(json['runtime']),
      voteAverage: _doubleValue(json['voteAverage'] ?? json['vote_average']),
      watched: _boolValue(json['watched'] ??
              json['isWatched'] ??
              effectiveProgress?['watched']) ??
          false,
      userRating:
          _doubleValue(json['userRating'] ?? effectiveProgress?['rating']),
    );
  }
}

class TvShowCredit {
  final int id;
  final String name;
  final String? role;
  final String? character;
  final String? profilePath;

  const TvShowCredit({
    required this.id,
    required this.name,
    this.role,
    this.character,
    this.profilePath,
  });

  factory TvShowCredit.fromJson(Map<String, dynamic> json) {
    final person = json['person'] is Map<String, dynamic>
        ? json['person'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return TvShowCredit(
      id: _intValue(json['personId'] ?? person['id'] ?? json['id']) ?? 0,
      name: _stringValue(
            json['name'] ?? person['name'] ?? json['personName'],
          ) ??
          'Unknown',
      role: _stringValue(
        json['job'] ??
            json['role'] ??
            json['knownForDepartment'] ??
            person['department'],
      ),
      character: _stringValue(
        json['character'] ?? json['characterName'] ?? json['roleName'],
      ),
      profilePath: _stringValue(
        json['profilePath'] ??
            json['profile_path'] ??
            json['profileImgUrl'] ??
            person['profilePath'] ??
            person['profile_path'] ??
            person['profileImgUrl'],
      ),
    );
  }
}

class TvShowCredits {
  final List<TvShowCredit> cast;
  final List<TvShowCredit> crew;

  const TvShowCredits({
    this.cast = const [],
    this.crew = const [],
  });

  factory TvShowCredits.fromJson(Map<String, dynamic> json) {
    return TvShowCredits(
      cast: _mapList(
          json['cast'] ?? json['credits']?['cast'], TvShowCredit.fromJson),
      crew: _mapList(
          json['crew'] ?? json['credits']?['crew'], TvShowCredit.fromJson),
    );
  }
}

class TvShowFriendSummary {
  final int watchedCount;
  final double? averageRating;
  final int followingCount;
  final String? highestName;
  final double? highestRating;
  final String? lowestName;
  final double? lowestRating;

  const TvShowFriendSummary({
    this.watchedCount = 0,
    this.averageRating,
    this.followingCount = 0,
    this.highestName,
    this.highestRating,
    this.lowestName,
    this.lowestRating,
  });

  factory TvShowFriendSummary.fromJson(Map<String, dynamic> json) {
    return TvShowFriendSummary(
      watchedCount:
          _intValue(json['watchedCount'] ?? json['friendsWatched']) ?? 0,
      averageRating: _doubleValue(json['averageRating']),
      followingCount:
          _intValue(json['followingCount'] ?? json['friendsFollowing']) ?? 0,
      highestName:
          _stringValue(json['highestName'] ?? json['highest']?['name']),
      highestRating:
          _doubleValue(json['highestRating'] ?? json['highest']?['rating']),
      lowestName: _stringValue(json['lowestName'] ?? json['lowest']?['name']),
      lowestRating:
          _doubleValue(json['lowestRating'] ?? json['lowest']?['rating']),
    );
  }
}

class TvShowFriendActivity {
  final String id;
  final String userName;
  final String action;
  final String? details;
  final double? rating;
  final String? createdAt;

  const TvShowFriendActivity({
    required this.id,
    required this.userName,
    required this.action,
    this.details,
    this.rating,
    this.createdAt,
  });

  factory TvShowFriendActivity.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return TvShowFriendActivity(
      id: _stringValue(json['id']) ?? '',
      userName: _stringValue(
            user['firstName'] ?? user['username'] ?? json['userName'],
          ) ??
          'Friend',
      action: _stringValue(json['action'] ?? json['type']) ?? 'updated',
      details: _stringValue(json['details'] ?? json['message']),
      rating: _doubleValue(json['rating']),
      createdAt: _stringValue(json['createdAt']),
    );
  }
}

List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) mapper) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(mapper)
      .toList(growable: false);
}

Map<int, Map<String, dynamic>> _episodeProgressByEpisodeId(dynamic value) {
  if (value is! Iterable) return const {};
  final entries = <int, Map<String, dynamic>>{};
  for (final item in value) {
    if (item is! Map<String, dynamic>) continue;
    final episodeId = _intValue(item['episodeId'] ?? item['episode']?['id']);
    if (episodeId == null) continue;
    entries[episodeId] = item;
  }
  return entries;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = _stringValue(value);
  return text == null ? const [] : [text];
}

List<String> _nameList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return _stringValue(item['name'] ?? item['title']);
          }
          return _stringValue(item);
        })
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }
  if (value is Map<String, dynamic>) {
    final name = _stringValue(value['name'] ?? value['title']);
    return name == null ? const [] : [name];
  }
  final text = _stringValue(value);
  return text == null ? const [] : [text];
}

List<String> _creatorNames(dynamic value) {
  if (value is Iterable) {
    final names = value
        .map((item) {
          if (item is Map<String, dynamic>) {
            final person = item['person'];
            if (person is Map<String, dynamic>) {
              return _stringValue(person['name']);
            }
            return _stringValue(item['name'] ?? item['title']);
          }
          return _stringValue(item);
        })
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    if (names.isNotEmpty) return names;
  }
  return _nameList(value);
}

String? _stringValue(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

double? _ratingValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.contains('/')) {
    return double.tryParse(text.split('/').first.trim());
  }
  if (text.endsWith('%')) {
    final percent = double.tryParse(text.replaceAll('%', '').trim());
    return percent == null ? null : percent / 10;
  }
  return double.tryParse(text);
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value);
  return null;
}
