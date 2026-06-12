class GroupInsightsResponse {
  final List<GroupInsightMovie> mostWatchedThisMonth;
  final List<GroupInsightMovie> mostDiscussedMovies;
  final List<GroupInsightMovie> highestRatedMovies;
  final List<GroupInsightReview> recentReviews;
  final List<GroupInsightMember> mostActiveMembers;

  const GroupInsightsResponse({
    this.mostWatchedThisMonth = const [],
    this.mostDiscussedMovies = const [],
    this.highestRatedMovies = const [],
    this.recentReviews = const [],
    this.mostActiveMembers = const [],
  });

  bool get isCompletelyEmpty =>
      mostWatchedThisMonth.isEmpty &&
      mostDiscussedMovies.isEmpty &&
      highestRatedMovies.isEmpty &&
      recentReviews.isEmpty &&
      mostActiveMembers.isEmpty;

  factory GroupInsightsResponse.fromJson(Map<String, dynamic> json) {
    List<GroupInsightMovie> parseMovies(String key) {
      final list = json[key] as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(GroupInsightMovie.fromJson)
          .toList(growable: false);
    }

    final reviewsRaw = json['recentReviews'] as List<dynamic>? ?? const [];
    final membersRaw = json['mostActiveMembers'] as List<dynamic>? ?? const [];

    return GroupInsightsResponse(
      mostWatchedThisMonth: parseMovies('mostWatchedThisMonth'),
      mostDiscussedMovies: parseMovies('mostDiscussedMovies'),
      highestRatedMovies: parseMovies('highestRatedMovies'),
      recentReviews: reviewsRaw
          .whereType<Map<String, dynamic>>()
          .map(GroupInsightReview.fromJson)
          .toList(growable: false),
      mostActiveMembers: membersRaw
          .whereType<Map<String, dynamic>>()
          .map(GroupInsightMember.fromJson)
          .toList(growable: false),
    );
  }
}

class GroupInsightMovie {
  final int? movieId;
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final int? year;
  final int watchCount;
  final int discussionCount;
  final double averageRating;
  final int ratingCount;
  final double ratingSpread;
  final String? latestDiscussionSnippet;
  final List<String> genres;
  final List<GroupInsightUser> watchers;

  const GroupInsightMovie({
    this.movieId,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.year,
    this.watchCount = 0,
    this.discussionCount = 0,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.ratingSpread = 0,
    this.latestDiscussionSnippet,
    this.genres = const [],
    this.watchers = const [],
  });

  factory GroupInsightMovie.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final usersRaw = (json['watchers'] ?? json['members'] ?? json['users'])
        as List<dynamic>?;

    return GroupInsightMovie(
      movieId: _parseInt(json['movieId'] ?? json['id'] ?? movie?['id']),
      title: (json['movieTitle'] ??
              json['movie_title'] ??
              json['title'] ??
              movie?['title'] ??
              movie?['name'] ??
              'Movie')
          .toString(),
      posterPath: _firstNonEmptyString([
        json['posterPath'],
        json['poster_path'],
        json['moviePosterPath'],
        json['movie_poster_path'],
        json['moviePosterUrl'],
        json['movie_poster_url'],
        json['posterUrl'],
        json['poster_url'],
        movie?['posterPath'],
        movie?['poster_path'],
        movie?['moviePosterPath'],
        movie?['movie_poster_path'],
        movie?['moviePosterUrl'],
        movie?['movie_poster_url'],
        movie?['posterUrl'],
        movie?['poster_url'],
      ]),
      releaseDate: _firstNonEmptyString([
        json['releaseDate'],
        json['release_date'],
        json['movieReleaseDate'],
        json['movie_release_date'],
        movie?['releaseDate'],
        movie?['release_date'],
      ]),
      year: _parseInt(json['year'] ?? json['releaseYear'] ?? movie?['year']),
      watchCount: _parseInt(json['watchCount'] ?? json['count']) ?? 0,
      discussionCount:
          _parseInt(json['discussionCount'] ?? json['messageCount']) ?? 0,
      averageRating:
          _parseDouble(json['averageRating'] ?? json['avgRating']) ?? 0,
      ratingCount: _parseInt(json['ratingCount'] ?? json['ratingsCount']) ?? 0,
      ratingSpread: _parseDouble(json['ratingSpread'] ??
              json['ratingVariance'] ??
              json['ratingStdDev'] ??
              json['rating_std_dev']) ??
          _ratingSpreadFromBounds(json),
      latestDiscussionSnippet:
          (json['latestDiscussionSnippet'] ?? json['latestSnippet']) as String?,
      genres: _parseGenres(json['genres'] ?? movie?['genres']),
      watchers: (usersRaw ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GroupInsightUser.fromJson)
          .toList(growable: false),
    );
  }
}

List<String> _parseGenres(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((genre) {
        if (genre is String) return genre.trim();
        if (genre is Map<String, dynamic>) {
          return (genre['name'] ?? genre['label'] ?? '').toString().trim();
        }
        return '';
      })
      .where((genre) => genre.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

double _ratingSpreadFromBounds(Map<String, dynamic> json) {
  final high = _parseDouble(json['maxRating'] ?? json['highestRating']);
  final low = _parseDouble(json['minRating'] ?? json['lowestRating']);
  if (high == null || low == null) return 0;
  return (high - low).abs();
}

class GroupInsightReview {
  final String id;
  final String? userId;
  final String reviewerName;
  final String reviewerUsername;
  final String? reviewerAvatarUrl;
  final int? movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final double rating;
  final String snippet;
  final String? createdAt;

  const GroupInsightReview({
    required this.id,
    this.userId,
    required this.reviewerName,
    required this.reviewerUsername,
    this.reviewerAvatarUrl,
    this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    this.rating = 0,
    this.snippet = '',
    this.createdAt,
  });

  factory GroupInsightReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final movie = json['movie'] as Map<String, dynamic>?;

    final reviewerName =
        (user?['username'] ?? user?['firstName'] ?? '').toString().trim();

    return GroupInsightReview(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? user?['id']) as String?,
      reviewerName: reviewerName.isEmpty ? 'User' : reviewerName,
      reviewerUsername: (json['reviewerUsername'] ??
              json['reviewer_username'] ??
              user?['username'] ??
              '')
          .toString(),
      reviewerAvatarUrl: _firstNonEmptyString([
        json['reviewerAvatarUrl'],
        json['reviewer_avatar_url'],
        user?['avatarUrl'],
        user?['avatar_url'],
      ]),
      movieId: _parseInt(json['movieId'] ?? movie?['id']),
      movieTitle: (json['movieTitle'] ??
              json['movie_title'] ??
              movie?['title'] ??
              movie?['name'] ??
              'Movie')
          .toString(),
      moviePosterPath: _firstNonEmptyString([
        json['moviePosterPath'],
        json['movie_poster_path'],
        json['moviePosterUrl'],
        json['movie_poster_url'],
        movie?['posterPath'],
        movie?['poster_path'],
        movie?['posterUrl'],
        movie?['poster_url'],
      ]),
      rating: _parseDouble(json['rating']) ?? 0,
      snippet: (json['snippet'] ?? json['body'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at']) as String?,
    );
  }
}

class GroupInsightMember {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final int activityCount;
  final int rank;
  final String? badge;

  const GroupInsightMember({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.activityCount = 0,
    this.rank = 0,
    this.badge,
  });

  factory GroupInsightMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final username = (json['username'] ?? user?['username'] ?? '').toString();
    final resolvedNameRaw =
        (username.isNotEmpty ? username : user?['firstName'] ?? '')
            .toString()
            .trim();
    final resolvedName = resolvedNameRaw.isEmpty ? username : resolvedNameRaw;

    return GroupInsightMember(
      id: (json['id'] ?? json['userId'] ?? user?['id'] ?? '').toString(),
      name: resolvedName,
      username: username,
      avatarUrl: _firstNonEmptyString([
        json['avatarUrl'],
        json['avatar_url'],
        user?['avatarUrl'],
        user?['avatar_url'],
      ]),
      activityCount: _parseInt(json['activityCount'] ?? json['count']) ?? 0,
      rank: _parseInt(json['rank']) ?? 0,
      badge: json['badge'] as String?,
    );
  }
}

class GroupInsightUser {
  final String id;
  final String username;
  final String? avatarUrl;

  const GroupInsightUser({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory GroupInsightUser.fromJson(Map<String, dynamic> json) {
    return GroupInsightUser(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      username: (json['username'] ?? json['name'] ?? '').toString(),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _firstNonEmptyString(List<dynamic> candidates) {
  for (final value in candidates) {
    if (value == null) continue;
    final str = value.toString().trim();
    if (str.isEmpty) continue;
    if (str == 'null' || str == 'undefined') continue;
    return str;
  }
  return null;
}
