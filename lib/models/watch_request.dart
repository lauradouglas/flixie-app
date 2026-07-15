import 'package:flixie_app/models/profile_avatar.dart';

class WatchRequestUser {
  final String id;
  final String username;
  final String? firstName;
  final String? lastName;
  final Map<String, dynamic>? iconColor;
  final ProfileAvatar? avatar;

  const WatchRequestUser({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.iconColor,
    this.avatar,
  });

  factory WatchRequestUser.fromJson(Map<String, dynamic> json) {
    return WatchRequestUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      iconColor: json['iconColor'] as Map<String, dynamic>?,
      avatar: json['avatar'] == null
          ? null
          : ProfileAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
    );
  }

  String get displayName {
    final first = firstName?.trim() ?? '';
    return first.isNotEmpty ? first : username;
  }
}

class WatchRequestMovieDetails {
  final int id;
  final String title;
  final String? posterPath;

  const WatchRequestMovieDetails({
    required this.id,
    required this.title,
    this.posterPath,
  });

  factory WatchRequestMovieDetails.fromJson(Map<String, dynamic> json) {
    return WatchRequestMovieDetails(
      id: _intValue(json['id']) ?? 0,
      title: json['title'] as String? ?? 'Unknown Movie',
      posterPath: json['posterPath'] as String?,
    );
  }
}

class WatchRequestParticipant {
  final WatchRequestUser? user;
  final String response;
  final DateTime? respondedAt;
  final DateTime? watchedAt;
  final double? rating;
  final String? reviewText;

  const WatchRequestParticipant({
    this.user,
    this.response = 'pending',
    this.respondedAt,
    this.watchedAt,
    this.rating,
    this.reviewText,
  });

  factory WatchRequestParticipant.fromJson(Map<String, dynamic> json) {
    return WatchRequestParticipant(
      user: json['user'] != null
          ? WatchRequestUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      response: (json['response'] ?? json['status'])?.toString() ?? 'pending',
      respondedAt: _dateTimeValue(json['respondedAt']),
      watchedAt: _dateTimeValue(json['watchedAt']),
      rating: _doubleValue(json['rating']),
      reviewText: json['reviewText'] as String?,
    );
  }

  bool get hasCompleted => watchedAt != null || rating != null;
}

class WatchScheduleProposal {
  final String id;
  final String proposerId;
  final DateTime? proposedFor;
  final String? message;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  const WatchScheduleProposal({
    required this.id,
    required this.proposerId,
    this.proposedFor,
    this.message,
    this.status = 'PENDING',
    this.createdAt,
    this.updatedAt,
  });

  factory WatchScheduleProposal.fromJson(Map<String, dynamic> json) {
    return WatchScheduleProposal(
      id: json['id']?.toString() ?? '',
      proposerId: (json['proposerId'] ?? json['userId'])?.toString() ?? '',
      proposedFor: _dateTimeValue(json['proposedFor']),
      message: json['message'] as String?,
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  String get normalizedStatus => status.toUpperCase();
  bool get isPending => normalizedStatus == 'PENDING';
}

class WatchConfirmation {
  final String id;
  final String userId;
  final bool watched;
  final int? rating;
  final String? reviewText;
  final String? createdAt;

  const WatchConfirmation({
    required this.id,
    required this.userId,
    required this.watched,
    this.rating,
    this.reviewText,
    this.createdAt,
  });

  factory WatchConfirmation.fromJson(Map<String, dynamic> json) {
    return WatchConfirmation(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      watched: _boolValue(json['watched']) ?? false,
      rating: _intValue(json['rating']),
      reviewText: json['reviewText'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class WatchRequestState {
  final WatchRequest request;
  final bool needsWatchConfirmation;

  const WatchRequestState({
    required this.request,
    required this.needsWatchConfirmation,
  });

  factory WatchRequestState.fromJson(Map<String, dynamic> json) {
    final requestJson = Map<String, dynamic>.from(
      json['request'] as Map<String, dynamic>,
    );
    requestJson['needsWatchConfirmation'] = json['needsWatchConfirmation'];
    return WatchRequestState(
      request: WatchRequest.fromJson(requestJson),
      needsWatchConfirmation:
          _boolValue(json['needsWatchConfirmation']) ?? false,
    );
  }
}

class WatchRequest {
  final String id;
  final String requesterId;
  final String recipientId;
  final String? message;
  final String status;
  final String? response;
  final int? movieId;
  final String type;
  final String? createdAt;
  final String? updatedAt;
  final DateTime? proposedDate;
  final DateTime? scheduledFor;
  final String scheduleStatus;
  final String? scheduledById;
  final String watchedStatus;
  final List<WatchScheduleProposal> scheduleProposals;
  final List<WatchConfirmation> watchConfirmations;
  final bool? needsWatchConfirmation;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? expiresAt;
  final DateTime? lastActivityAt;
  final List<WatchRequestParticipant> participants;
  final bool? hasCurrentUserAccepted;
  final bool? hasCurrentUserCompleted;
  final bool? canSchedule;
  final bool? canComplete;
  final bool? canCancel;
  final WatchRequestUser? requester;
  final WatchRequestUser? recipient;
  final WatchRequestUser? createdBy;
  final WatchRequestMovieDetails? movie;

  const WatchRequest({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    this.message,
    required this.status,
    this.response,
    this.movieId,
    required this.type,
    this.createdAt,
    this.updatedAt,
    this.proposedDate,
    this.scheduledFor,
    this.scheduleStatus = 'NONE',
    this.scheduledById,
    this.watchedStatus = 'NOT_DUE',
    this.scheduleProposals = const [],
    this.watchConfirmations = const [],
    this.needsWatchConfirmation,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
    this.expiresAt,
    this.lastActivityAt,
    this.participants = const [],
    this.hasCurrentUserAccepted,
    this.hasCurrentUserCompleted,
    this.canSchedule,
    this.canComplete,
    this.canCancel,
    this.requester,
    this.recipient,
    this.createdBy,
    this.movie,
  });

  factory WatchRequest.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'] as Map<String, dynamic>?;
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    final participantsRaw = json['participants'] as List<dynamic>? ?? [];
    final proposalsRaw = json['scheduleProposals'] as List<dynamic>? ?? [];
    final confirmationsRaw = json['watchConfirmations'] as List<dynamic>? ?? [];
    final requester = json['requester'] as Map<String, dynamic>?;
    final recipient = json['recipient'] as Map<String, dynamic>?;

    return WatchRequest(
      id: json['id']?.toString() ?? '',
      requesterId:
          (json['requesterId'] ?? json['createdById'] ?? createdBy?['id'])
                  ?.toString() ??
              '',
      recipientId: json['recipientId']?.toString() ?? '',
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'open',
      response: json['response'] as String?,
      movieId: _intValue(json['movieId'] ?? movie?['id']),
      type: json['type'] as String? ?? 'MOVIE_WATCH_REQUEST',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      proposedDate: _dateTimeValue(json['proposedDate']),
      scheduledFor: _dateTimeValue(json['scheduledFor']),
      scheduleStatus: json['scheduleStatus']?.toString() ?? 'NONE',
      scheduledById: json['scheduledById']?.toString(),
      watchedStatus: json['watchedStatus']?.toString() ?? 'NOT_DUE',
      scheduleProposals: proposalsRaw
          .whereType<Map<String, dynamic>>()
          .map(WatchScheduleProposal.fromJson)
          .toList(),
      watchConfirmations: confirmationsRaw
          .whereType<Map<String, dynamic>>()
          .map(WatchConfirmation.fromJson)
          .toList(),
      needsWatchConfirmation: _boolValue(json['needsWatchConfirmation']),
      acceptedAt: _dateTimeValue(json['acceptedAt']),
      completedAt: _dateTimeValue(json['completedAt']),
      cancelledAt: _dateTimeValue(json['cancelledAt']),
      expiresAt: _dateTimeValue(json['expiresAt']),
      lastActivityAt: _dateTimeValue(json['lastActivityAt']),
      participants: participantsRaw
          .whereType<Map<String, dynamic>>()
          .map(WatchRequestParticipant.fromJson)
          .toList(),
      hasCurrentUserAccepted: _boolValue(json['hasCurrentUserAccepted']),
      hasCurrentUserCompleted: _boolValue(json['hasCurrentUserCompleted']),
      canSchedule: _boolValue(json['canSchedule']),
      canComplete: _boolValue(json['canComplete']),
      canCancel: _boolValue(json['canCancel']),
      requester:
          requester != null ? WatchRequestUser.fromJson(requester) : null,
      recipient:
          recipient != null ? WatchRequestUser.fromJson(recipient) : null,
      createdBy:
          createdBy != null ? WatchRequestUser.fromJson(createdBy) : null,
      movie: movie != null ? WatchRequestMovieDetails.fromJson(movie) : null,
    );
  }

  /// Returns the other user (not the current user) in this request.
  WatchRequestUser? otherUser(String myUserId) {
    if (participants.isNotEmpty) {
      for (final participant in participants) {
        final user = participant.user;
        if (user != null && user.id != myUserId) return user;
      }
    }
    if (requesterId == myUserId) return recipient;
    return requester ?? createdBy;
  }

  WatchRequestParticipant? participantFor(String userId) {
    for (final participant in participants) {
      if (participant.user?.id == userId) return participant;
    }
    return null;
  }

  String get normalizedStatus => status.toLowerCase();
  String get normalizedType => type.toUpperCase();
  String get normalizedScheduleStatus => scheduleStatus.toUpperCase();
  String get normalizedWatchedStatus => watchedStatus.toUpperCase();

  bool get isWatchRequest =>
      normalizedType == 'MOVIE_WATCH_REQUEST' ||
      normalizedType == 'SHOW_WATCH_REQUEST';
  bool get isPending =>
      normalizedStatus == 'pending' || normalizedStatus == 'open';
  bool get isAccepted => normalizedStatus == 'accepted';
  bool get isScheduled => normalizedStatus == 'scheduled';
  bool get isCompleted =>
      normalizedStatus == 'completed' || normalizedStatus == 'finalised';
  bool get isCancelled =>
      normalizedStatus == 'cancelled' || normalizedStatus == 'canceled';
  bool get isExpired => normalizedStatus == 'expired';
  bool get isDeclined => normalizedStatus == 'declined';
  bool get isTerminal => isCompleted || isCancelled || isExpired || isDeclined;

  bool canScheduleFor(String userId) =>
      canSchedule ?? ((isAccepted || isScheduled) && !isTerminal);

  bool canCompleteFor(String userId) =>
      canComplete ??
      ((isAccepted || isScheduled) &&
          hasCurrentUserAccepted == true &&
          hasCurrentUserCompleted != true);

  bool canCancelFor(String userId) =>
      canCancel ??
      (!isTerminal && (requesterId == userId || isAccepted || isScheduled));

  WatchScheduleProposal? get latestPendingProposal {
    final pending = scheduleProposals.where((p) => p.isPending).toList()
      ..sort((a, b) => _dateTimeValue(b.createdAt)
          .compareNullable(_dateTimeValue(a.createdAt)));
    return pending.isEmpty ? null : pending.first;
  }

  bool hasCurrentUserConfirmed(String userId) =>
      watchConfirmations.any((c) => c.userId == userId);

  bool get canProposeSchedule => isWatchRequest && isAccepted;

  bool canRespondToProposal(String userId) {
    final proposal = latestPendingProposal;
    return proposal != null && proposal.proposerId != userId;
  }

  bool canConfirmWatchedFor(String userId) =>
      needsWatchConfirmation == true && !hasCurrentUserConfirmed(userId);
}

extension on DateTime? {
  int compareNullable(DateTime? other) {
    final left = this ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = other ?? DateTime.fromMillisecondsSinceEpoch(0);
    return left.compareTo(right);
  }
}

DateTime? _dateTimeValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
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

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value);
  return null;
}
