import 'package:flixie_app/features/movies/models/external_watch_invite.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/watchlist_movie.dart';

class MovieWatchEntry {
  final FriendshipUser? companion;
  final List<FriendshipUser> companions;
  // Read-only diary context; group attendees are not direct-plan edit selections.
  final List<FriendshipUser> groupCompanions;
  List<FriendshipUser> get allCompanions =>
      companions.isNotEmpty ? companions : [if (companion != null) companion!];
  final ExternalWatchInvite? externalInvite;
  final String? planId, reviewBody, reviewTitle;
  final bool reviewContainsSpoilers;
  final String id;
  final String userId;
  final int movieId;
  final String? watchedAt;
  final double? rating;
  final bool? recommended;
  final String? notes;
  final bool watchedAtCinema;
  final bool removed;
  final String? createdAt;
  final String? updatedAt;
  final WatchlistMovieDetails? movie;

  const MovieWatchEntry({
    this.companion,
    this.companions = const [],
    this.groupCompanions = const [],
    this.externalInvite,
    this.planId,
    this.reviewBody,
    this.reviewTitle,
    this.reviewContainsSpoilers = false,
    this.watchedAtCinema = false,
    required this.id,
    required this.userId,
    required this.movieId,
    this.watchedAt,
    this.rating,
    this.recommended,
    this.notes,
    required this.removed,
    this.createdAt,
    this.updatedAt,
    this.movie,
  });

  factory MovieWatchEntry.fromJson(Map<String, dynamic> json) {
    final confirmations =
        (json['watchPlanConfirmations'] as List? ?? []).whereType<Map>();
    final request = confirmations.firstOrNull?['request'] as Map?;
    final other = request == null
        ? json['companion'] as Map?
        : request[request['requesterId'] == json['userId']
            ? 'recipient'
            : 'requester'] as Map?;
    final people = <String, FriendshipUser>{};
    for (final confirmation in confirmations) {
      final plan = confirmation['request'] as Map?;
      for (final participant
          in (plan?['participants'] as List? ?? const []).whereType<Map>()) {
        final user = participant['user'];
        if (user is Map && user['id'] != json['userId']) {
          final friend =
              FriendshipUser.fromJson(Map<String, dynamic>.from(user));
          people[friend.id] = friend;
        }
      }
      final person = plan?[
          plan['requesterId'] == json['userId'] ? 'recipient' : 'requester'];
      if (person is Map) {
        final friend =
            FriendshipUser.fromJson(Map<String, dynamic>.from(person));
        people[friend.id] = friend;
      }
    }
    for (final person in (json['companions'] as List? ?? []).whereType<Map>()) {
      final friend = FriendshipUser.fromJson(Map<String, dynamic>.from(person));
      people[friend.id] = friend;
    }
    final review =
        (json['reviews'] as List? ?? []).whereType<Map>().firstOrNull;
    final groupPeople = <String, FriendshipUser>{};
    for (final link
        in (json['groupPlanResponses'] as List? ?? const []).whereType<Map>()) {
      for (final response
          in (link['request']?['responses'] as List? ?? const [])
              .whereType<Map>()) {
        final person = response['responder'];
        if (person is Map && person['id'] != json['userId']) {
          final user =
              FriendshipUser.fromJson(Map<String, dynamic>.from(person));
          groupPeople[user.id] = user;
        }
      }
    }
    for (final person
        in (json['groupCompanions'] as List? ?? const []).whereType<Map>()) {
      final user = FriendshipUser.fromJson(Map<String, dynamic>.from(person));
      groupPeople[user.id] = user;
    }
    return MovieWatchEntry(
      groupCompanions: groupPeople.values.toList(),
      externalInvite: json['externalInvite'] is Map<String, dynamic>
          ? ExternalWatchInvite.fromJson(
              json['externalInvite'] as Map<String, dynamic>)
          : null,
      companions: people.values.toList(),
      companion: other == null
          ? null
          : FriendshipUser.fromJson(Map<String, dynamic>.from(other)),
      planId: request?['id']?.toString() ?? json['planId']?.toString(),
      reviewTitle:
          review?['title']?.toString() ?? json['reviewTitle']?.toString(),
      reviewBody: review?['body']?.toString() ?? json['reviewBody']?.toString(),
      reviewContainsSpoilers: review?['containsSpoilers'] == true ||
          json['reviewContainsSpoilers'] == true,
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: _parseInt(json['movieId']) ?? 0,
      watchedAt: json['watchedAt'] as String?,
      rating: _parseDouble(json['rating']),
      recommended: json['recommended'] as bool?,
      notes: json['notes'] as String?,
      watchedAtCinema: json['watchedAtCinema'] == true,
      removed: json['removed'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      movie: json['movie'] is Map<String, dynamic>
          ? WatchlistMovieDetails.fromJson(
              json['movie'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (groupCompanions.isNotEmpty)
        'groupCompanions': [
          for (final p in groupCompanions)
            {
              'id': p.id,
              'username': p.username,
              'firstName': p.firstName,
              'avatar': p.avatar?.toJson(),
              'iconColor': p.iconColor,
              'profileBadges': p.profileBadges
            }
        ],
      if (externalInvite != null) 'externalInvite': externalInvite!.toJson(),
      if (allCompanions.isNotEmpty)
        'companions': [
          for (final friend in allCompanions)
            {
              'id': friend.id,
              'username': friend.username,
              'firstName': friend.firstName,
              'avatar': friend.avatar?.toJson(),
              'iconColor': friend.iconColor,
              'profileBadges': friend.profileBadges
            }
        ],
      if (companion != null)
        'companion': {
          'id': companion!.id,
          'username': companion!.username,
          'firstName': companion!.firstName,
          'iconColor': companion!.iconColor,
          'avatar': companion!.avatar?.toJson(),
          'profileBadges': companion!.profileBadges
        },
      if (planId != null) 'planId': planId,
      if (reviewTitle != null) 'reviewTitle': reviewTitle,
      if (reviewBody != null) 'reviewBody': reviewBody,
      'reviewContainsSpoilers': reviewContainsSpoilers,
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'watchedAt': watchedAt,
      'rating': rating,
      'recommended': recommended,
      'notes': notes,
      'watchedAtCinema': watchedAtCinema,
      'removed': removed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (movie != null) 'movie': movie!.toJson(),
    };
  }
}

class LogMovieWatchRequest {
  final String? draftId, companionId, reviewBody, externalCompanionName;
  final List<String>? companionIds;
  final bool? watchedAtCinema;
  final bool containsSpoilers;

  final int movieId;
  final String? watchedAt;
  final double? rating;
  final bool? recommended;
  final String? notes;

  const LogMovieWatchRequest({
    this.draftId,
    this.watchedAtCinema,
    this.externalCompanionName,
    this.companionId,
    this.companionIds,
    this.reviewBody,
    this.containsSpoilers = false,
    required this.movieId,
    this.watchedAt,
    this.rating,
    this.recommended,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (draftId != null) 'draftId': draftId,
      if (watchedAtCinema != null) 'watchedAtCinema': watchedAtCinema,
      if (externalCompanionName != null)
        'externalCompanionName': externalCompanionName,
      if (draftId != null) 'watchedAt': watchedAt,
      if (companionId != null) 'companionId': companionId,
      if (companionIds != null) 'companionIds': companionIds,
      if (reviewBody != null) 'reviewBody': reviewBody,
      'containsSpoilers': containsSpoilers,
      'movieId': movieId,
      if (watchedAt != null) 'watchedAt': watchedAt,
      'rating': rating,
      'recommended': recommended,
      'notes': notes,
    };
  }
}

class UpdateMovieWatchRequest {
  final String? draftId, companionId, reviewBody, externalCompanionName;
  final List<String>? companionIds;
  final bool? watchedAtCinema;
  final bool containsSpoilers;
  final int? movieId;

  final double? rating;
  final bool? recommended;
  final String? notes;
  final String? watchedAt;

  const UpdateMovieWatchRequest({
    this.draftId,
    this.watchedAtCinema,
    this.externalCompanionName,
    this.companionId,
    this.companionIds,
    this.reviewBody,
    this.containsSpoilers = false,
    this.movieId,
    this.rating,
    this.recommended,
    this.notes,
    this.watchedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (draftId != null) 'draftId': draftId,
      if (watchedAtCinema != null) 'watchedAtCinema': watchedAtCinema,
      if (externalCompanionName != null)
        'externalCompanionName': externalCompanionName,
      if (draftId != null) 'watchedAt': watchedAt,
      if (companionId != null) 'companionId': companionId,
      if (companionIds != null) 'companionIds': companionIds,
      if (reviewBody != null) 'reviewBody': reviewBody,
      'containsSpoilers': containsSpoilers,
      if (movieId != null) 'movieId': movieId,
      if (watchedAt != null) 'watchedAt': watchedAt,
      'rating': rating,
      'recommended': recommended,
      'notes': notes,
    };
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
