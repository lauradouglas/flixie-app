import 'package:flutter/foundation.dart';

import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/profile_avatar.dart';

enum ActivityListType {
  movieWatchlist('watchlist-movie'),
  showWatchlist('watchlist-show'),
  movieWatched('watched-movie'),
  showWatched('watched-show'),
  favoriteMovie('favorite-movie'),
  favoriteShow('favorite-show'),
  favoritePerson('favorite-person'),
  movieRating('movie-rating'),
  showRating('show-rating'),
  movieReview('movie-review'),
  showReview('show-review'),
  watchRequestSent('watch-request-sent'),
  watchRequestAccepted('watch-request-accepted'),
  watchRequest('watch-request'),
  unknown('unknown');

  const ActivityListType(this.value);
  final String value;

  static ActivityListType fromString(String? raw) {
    // Normalize underscore variants used by the group activity API
    final normalized = raw?.replaceAll('_', '-');
    for (final t in values) {
      if (t.value == normalized) return t;
    }
    return unknown;
  }
}

class ActivityListItem {
  final String id;
  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final int? movieId;
  final int? showId;
  final int? personId;
  final bool removed;
  final String createdAt;
  final String updatedAt;
  final ActivityListType type;
  final String? mediaTitle;
  final String? mediaPosterPath;
  final double? mediaRating;
  final String? watchedAt;
  final int? watchCount;
  final bool isRewatch;
  final String? notes;
  final Review? reviewData;
  final int activityScore;
  final ProfileAvatar? avatar;

  String get timestamp {
    if (watchedAt != null && watchedAt!.isNotEmpty) return watchedAt!;
    if (createdAt.isNotEmpty) return createdAt;
    return updatedAt;
  }

  const ActivityListItem({
    required this.id,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.movieId,
    this.showId,
    this.personId,
    required this.removed,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    this.mediaTitle,
    this.mediaPosterPath,
    this.mediaRating,
    this.watchedAt,
    this.watchCount,
    this.isRewatch = false,
    this.notes,
    this.reviewData,
    this.activityScore = 0,
    this.avatar,
  });

  ActivityListItem copyWith({ProfileAvatar? avatar}) => ActivityListItem(
        id: id,
        userId: userId,
        username: username,
        firstName: firstName,
        lastName: lastName,
        movieId: movieId,
        showId: showId,
        personId: personId,
        removed: removed,
        createdAt: createdAt,
        updatedAt: updatedAt,
        type: type,
        mediaTitle: mediaTitle,
        mediaPosterPath: mediaPosterPath,
        mediaRating: mediaRating,
        watchedAt: watchedAt,
        watchCount: watchCount,
        isRewatch: isRewatch,
        notes: notes,
        reviewData: reviewData,
        activityScore: activityScore,
        avatar: avatar ?? this.avatar,
      );

  factory ActivityListItem.fromJson(Map<String, dynamic> json) {
    // Group activity API nests user info; friends API uses top-level fields
    final user = json['user'] as Map<String, dynamic>? ??
        json['requester'] as Map<String, dynamic>?;
    final movie = json['movie'] as Map<String, dynamic>?;
    final show = json['show'] as Map<String, dynamic>?;
    final person = json['person'] as Map<String, dynamic>?;
    final review = json['review'] as Map<String, dynamic>?;
    final rawType = json['type'] as String?;
    final type = _resolveActivityType(rawType);
    final parsedWatchCount =
        _parseInt(json['watchCount'] ?? json['totalWatchCount']);
    final normalizedType = rawType?.toLowerCase().replaceAll('_', '-');
    final isRewatch = json['isRewatch'] == true ||
        json['rewatch'] == true ||
        normalizedType == 'rewatched' ||
        (parsedWatchCount != null && parsedWatchCount > 1);
    final userId = user?['id'] as String? ??
        json['userId'] as String? ??
        json['requesterId'] as String? ??
        '';
    Review? reviewData;
    final isReviewType = type == ActivityListType.movieReview ||
        type == ActivityListType.showReview;
    // API returns review fields flat at the top level, not nested under 'review'
    final src = review ?? (isReviewType ? json : null);
    if (src != null && isReviewType) {
      try {
        reviewData = Review.fromJson(<String, dynamic>{
          'id': (src['id'] ?? '').toString(),
          'userId': (src['userId'] ?? userId).toString(),
          'movieId': src['movieId'] ?? json['movieId'],
          'showId': src['showId'] ?? json['showId'],
          'rating': src['rating'] ?? 0,
          'title': src['title'] ?? '',
          'body': src['body'] ?? '',
          'upvotes': src['upvotes'] ?? 0,
          'downvotes': src['downvotes'] ?? 0,
          'containsSpoilers': src['containsSpoilers'] ?? false,
          'language': src['language'] ?? 'en',
          'recommended': src['recommended'] ?? true,
          'createdAt': src['createdAt'] ?? '',
          'updatedAt': src['updatedAt'] ?? '',
          if (src['user'] != null) 'user': src['user'],
          if (src['reactions'] != null) 'reactions': src['reactions'],
          if (src['myReaction'] != null) 'myReaction': src['myReaction'],
          if (src['movie'] != null)
            'movieTitle': (src['movie'] as Map<String, dynamic>)['title'],
        });
      } catch (e, st) {
        debugPrint('[ActivityListItem] Review.fromJson failed: $e\n$st');
        reviewData = null;
      }
    }
    return ActivityListItem(
      id: json['id']?.toString() ?? '',
      userId: userId,
      username:
          user?['username'] as String? ?? json['username'] as String? ?? '',
      firstName:
          user?['firstName'] as String? ?? json['firstName'] as String? ?? '',
      lastName:
          user?['lastName'] as String? ?? json['lastName'] as String? ?? '',
      movieId: _parseInt(json['movieId']),
      showId: _parseInt(json['showId']),
      personId: _parseInt(json['personId']),
      removed: json['removed'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      type: type,
      mediaTitle: movie?['title'] as String? ??
          show?['title'] as String? ??
          person?['name'] as String?,
      mediaPosterPath: movie?['posterPath'] as String? ??
          show?['posterPath'] as String? ??
          person?['profileImgUrl'] as String?,
      mediaRating: (json['rating'] as num?)?.toDouble() ??
          (review?['rating'] as num?)?.toDouble(),
      watchedAt: json['watchedAt'] as String?,
      watchCount: parsedWatchCount,
      isRewatch: isRewatch,
      notes: json['notes'] as String?,
      reviewData: reviewData,
      avatar: (user?['avatar'] ?? json['avatar']) == null
          ? null
          : ProfileAvatar.fromJson(
              (user?['avatar'] ?? json['avatar']) as Map<String, dynamic>),
      activityScore: _parseInt(json['activityScore']) ?? 0,
    );
  }
}

ActivityListType _resolveActivityType(String? rawType) {
  final resolved = ActivityListType.fromString(rawType);
  if (resolved != ActivityListType.unknown) return resolved;

  final normalized = rawType?.toLowerCase().replaceAll('_', '-');
  switch (normalized) {
    case 'added-review':
      return ActivityListType.movieReview;
    case 'rewatched':
    case 'watched':
      return ActivityListType.movieWatched;
    case 'added-to-favourites':
    case 'added-to-favorites':
      return ActivityListType.favoriteMovie;
    case 'added-to-watchlist':
      return ActivityListType.movieWatchlist;
    case 'rated':
    case 'rated-9-plus':
      return ActivityListType.movieRating;
    default:
      return ActivityListType.unknown;
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
