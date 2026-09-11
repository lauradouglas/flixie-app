import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/watch_request.dart';

class FlixieNotification {
  // Notification type constants
  static const String friendRequest = 'FRIEND_REQUEST';
  static const String groupRequest = 'GROUP_REQUEST';
  static const String groupInvite = 'GROUP_INVITE';
  static const String movieWatchRequest = 'MOVIE_WATCH_REQUEST';
  static const String showWatchRequest = 'SHOW_WATCH_REQUEST';
  static const String listShared = 'LIST_SHARED';
  static const String referralJoined = 'REFERRAL_JOINED';

  // Notification action constants
  static const String actionSent = 'SENT';
  static const String actionReceived = 'RECEIVED';
  static const String actionAccepted = 'ACCEPTED';
  static const String actionDeclined = 'DECLINED';

  final String? id;
  final String userId;
  final String type;
  final String? action;

  /// Immutable lifecycle event for a notification.  Unlike [action], this
  /// describes what happened to the Watch Plan rather than a response state.
  final String? event;
  final String message;
  final bool? read;
  final bool? closed;
  final String? relatedId;
  final String? linkId;
  final String? notificationReceived;
  final String? createdAt;
  final String? updatedAt;

  /// The related user (e.g. the sender of a friend request).
  final Map<String, dynamic>? senderUser;

  /// The raw link object from the API (contains embedded request/groupRequest).
  final Map<String, dynamic>? link;
  final Map<String, dynamic>? data;

  const FlixieNotification({
    this.id,
    required this.userId,
    required this.type,
    this.action,
    this.event,
    required this.message,
    this.read,
    this.closed,
    this.relatedId,
    this.linkId,
    this.notificationReceived,
    this.createdAt,
    this.updatedAt,
    this.senderUser,
    this.link,
    this.data,
  });

  /// Whether this notification is a request type that can be accepted/declined.
  bool get isRequest =>
      type == friendRequest ||
      type == groupRequest ||
      type == groupInvite ||
      type == movieWatchRequest ||
      type == showWatchRequest;

  /// Whether this notification is still pending a response.
  bool get isPending => action == actionReceived;

  bool get isRead => read ?? false;

  String? get category => data?['category']?.toString();

  /// Canonical Watch Plan event, with a compatibility bridge for notifications
  /// persisted before `event` was returned by the API.
  String? get watchPlanEvent {
    final raw =
        event ?? data?['event']?.toString() ?? data?['type']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return switch (raw.toUpperCase()) {
      'NEW_WATCH_REQUEST' => 'PLAN_INVITED',
      'REQUEST_ACCEPTED' => 'PLAN_ACCEPTED',
      'REQUEST_DECLINED' => 'PLAN_DECLINED',
      'DATETIME_PROPOSED' => 'SCHEDULE_PROPOSED',
      'DATETIME_ACCEPTED' => 'SCHEDULE_ACCEPTED',
      'DATETIME_DECLINED' => 'SCHEDULE_DECLINED',
      'CURRENT_TIME_KEPT' => 'SCHEDULE_KEPT',
      'REQUEST_SCHEDULED' => 'PLAN_SCHEDULED',
      'REQUEST_RESCHEDULED' => 'PLAN_RESCHEDULED',
      'LOCATION_CHANGED' => 'LOCATION_UPDATED',
      'REQUEST_CANCELLED' => 'PLAN_CANCELLED',
      'MOVIE_PROPOSED' => 'TITLE_PROPOSED',
      'MOVIE_SELECTED' => 'TITLE_SELECTED',
      'EVERYONE_RATED' => 'ALL_PARTICIPANTS_LOGGED',
      final value => value,
    };
  }

  bool get isWatchPlanNotification {
    const watchPlanEvents = {
      'PLAN_INVITED',
      'PLAN_ACCEPTED',
      'PLAN_DECLINED',
      'CANDIDATE_ADDED',
      'CANDIDATE_REMOVED',
      'CHOICES_SUBMITTED',
      'CHOICES_SAVED',
      'CHOICES_COMPLETE',
      'TITLE_PROPOSED',
      'TITLE_SELECTED',
      'TITLE_SELECTION_REOPENED',
      'SCHEDULE_PROPOSED',
      'SCHEDULE_ACCEPTED',
      'SCHEDULE_DECLINED',
      'SCHEDULE_KEPT',
      'PLAN_SCHEDULED',
      'PLAN_RESCHEDULED',
      'LOCATION_UPDATED',
      'PLAN_CANCELLED',
      'PLAN_DUE_SOON',
      'PLAN_READY_TO_LOG',
      'PARTICIPANT_LOGGED',
      'ALL_PARTICIPANTS_LOGGED',
      'RECAP_UPDATED',
    };
    return category == 'WATCH_PLAN' ||
        watchPlanEvents.contains(watchPlanEvent) ||
        type == movieWatchRequest ||
        type == showWatchRequest ||
        type == groupRequest;
  }

  String? get route {
    final value = data?['route']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasMultipleWatchPlanOptions =>
      int.tryParse(data?['candidateCount']?.toString() ?? '') != null &&
      int.parse(data!['candidateCount'].toString()) > 1;

  String get receivedAt => notificationReceived ?? createdAt ?? updatedAt ?? '';

  Map<String, dynamic>? get _linkOtherUser {
    final l = link;
    if (l == null) return senderUser;
    final request =
        (l['request'] ?? l['groupRequest']) as Map<String, dynamic>?;
    if (request == null) return senderUser;
    final requester = request['requester'] as Map<String, dynamic>?;
    final recipient = request['recipient'] as Map<String, dynamic>?;
    final requesterId =
        request['requesterId'] as String? ?? requester?['id'] as String?;
    if (requesterId == userId) return recipient;
    return requester;
  }

  String get senderName {
    final u = _linkOtherUser;
    if (u == null) return '';
    return u['username'] as String? ?? '';
  }

  String? get senderId {
    final linkedId = _linkOtherUser?['id']?.toString();
    if (linkedId != null && linkedId.isNotEmpty) return linkedId;
    final directId = senderUser?['id']?.toString();
    if (directId != null && directId.isNotEmpty) return directId;
    final payloadId =
        data?['senderId']?.toString() ?? data?['actorId']?.toString();
    return payloadId == null || payloadId.isEmpty ? null : payloadId;
  }

  String? get senderInitials {
    final u = _linkOtherUser;
    if (u == null) return null;
    // final initials = u['initials'] as String?;
    // if (initials != null && initials.isNotEmpty) return initials;
    final username = u['username'] as String? ?? '';
    return username.isNotEmpty ? username[0].toUpperCase() : null;
  }

  Map<String, dynamic>? get senderIconColor =>
      (_linkOtherUser)?['iconColor'] as Map<String, dynamic>?;

  ProfileAvatar? get senderAvatar {
    final value = _linkOtherUser?['avatar'];
    return value is Map<String, dynamic> ? ProfileAvatar.fromJson(value) : null;
  }

  /// The movie/show title embedded in a watch request link, if present.
  /// The poster path for the movie/show embedded in any request link.
  String? get watchMediaPosterPath {
    final payloadPoster = data?['posterPath']?.toString();
    if (payloadPoster != null && payloadPoster.isNotEmpty) return payloadPoster;
    final l = link;
    if (l == null) return null;
    final request =
        (l['request'] ?? l['groupRequest']) as Map<String, dynamic>?;
    if (request == null) return null;
    final movie = request['movie'] as Map<String, dynamic>?;
    if (movie != null) return movie['posterPath'] as String?;
    final show = request['show'] as Map<String, dynamic>?;
    return show?['posterPath'] as String?;
  }

  String? get watchMediaTitle {
    final payloadTitle = data?['mediaTitle']?.toString();
    if (payloadTitle != null && payloadTitle.isNotEmpty) return payloadTitle;
    final l = link;
    if (l == null) return null;
    final request =
        (l['request'] ?? l['groupRequest']) as Map<String, dynamic>?;
    if (request == null) return null;
    final movie = request['movie'] as Map<String, dynamic>?;
    if (movie != null) return movie['title'] as String?;
    final show = request['show'] as Map<String, dynamic>?;
    return show?['title'] as String?;
  }

  Map<String, dynamic>? get _linkedWatchRequest {
    final l = link;
    if (l == null) return null;
    return l['request'] as Map<String, dynamic>?;
  }

  WatchRequest? get linkedWatchRequest {
    final request = _linkedWatchRequest;
    return request == null ? null : WatchRequest.fromJson(request);
  }

  DateTime? get watchRequestScheduledFor {
    final raw = _linkedWatchRequest?['scheduledFor'];
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  DateTime? get watchRequestProposedFor {
    final raw = (_linkedWatchRequest ??
        link?['groupRequest'] as Map<String, dynamic>?)?['proposedDate'];
    return raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
  }

  String? get watchRequestLocation {
    final request =
        _linkedWatchRequest ?? link?['groupRequest'] as Map<String, dynamic>?;
    return (request?['location'] ?? request?['locationLabel'])?.toString();
  }

  String? get watchRequestScheduleStatus {
    return _linkedWatchRequest?['scheduleStatus'] as String?;
  }

  Map<String, dynamic>? get latestWatchScheduleProposal {
    final raw = _linkedWatchRequest?['scheduleProposals'];
    if (raw is! List) return null;
    final proposals = raw.whereType<Map<String, dynamic>>().toList()
      ..sort((a, b) {
        final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    return proposals.isEmpty ? null : proposals.first;
  }

  /// The movie ID embedded in a watch request link, if present.
  /// Reads `request.movieId` first, then falls back to `request.movie.id`.
  int? get watchMovieId {
    final l = link;
    if (l == null) return null;
    final request = (l['request']) as Map<String, dynamic>?;
    if (request == null) return null;
    // Prefer top-level movieId field
    final raw = request['movieId'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    // Fallback: read from embedded movie object
    final movie = request['movie'] as Map<String, dynamic>?;
    final movieRaw = movie?['id'];
    if (movieRaw is int) return movieRaw;
    if (movieRaw is String) return int.tryParse(movieRaw);
    return null;
  }

  /// Detail route for the media represented by this notification. Payload
  /// values are preferred so an older linked plan can still open its title.
  String? get watchMediaRoute {
    int? asInt(Object? value) => value is int
        ? value
        : value is String
            ? int.tryParse(value)
            : null;
    final request =
        (link?['request'] ?? link?['groupRequest']) as Map<String, dynamic>?;
    final movieId = asInt(data?['movieId']) ??
        asInt(request?['movieId']) ??
        asInt((request?['movie'] as Map<String, dynamic>?)?['id']);
    if (movieId != null) return '/movies/$movieId?source=notification';
    final showId = asInt(data?['showId']) ??
        asInt(request?['showId']) ??
        asInt((request?['show'] as Map<String, dynamic>?)?['id']);
    return showId == null ? null : '/shows/$showId?source=notification';
  }

  /// The movie title embedded in a group watch request link.
  String? get groupWatchMovieTitle {
    final l = link;
    if (l == null) return null;
    final gr = l['groupRequest'] as Map<String, dynamic>?;
    if (gr == null) return null;
    // Direct field from backend GroupWatchRequest shape
    final direct = gr['movieTitle'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    // Fallback: embedded movie object
    final movie = gr['movie'] as Map<String, dynamic>?;
    return movie?['title'] as String?;
  }

  /// The TMDB movie id embedded in a group watch request link.
  int? get groupWatchMovieId {
    final l = link;
    if (l == null) return null;
    final gr = l['groupRequest'] as Map<String, dynamic>?;
    if (gr == null) return null;
    // Backend stores as 'movieId'; also check 'mediaId' for compatibility
    final raw = gr['movieId'] ?? gr['mediaId'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// The group name embedded in a group watch request link.
  String? get groupWatchGroupName {
    final payloadName = data?['groupName']?.toString();
    if (payloadName != null && payloadName.isNotEmpty) return payloadName;
    final l = link;
    if (l == null) return null;
    final gr = l['groupRequest'] as Map<String, dynamic>?;
    if (gr == null) return null;
    final group = gr['group'] as Map<String, dynamic>?;
    return group?['name'] as String?;
  }

  /// The group owning a group-scoped Watch Plan notification.
  String? get groupWatchGroupId {
    final payloadId = data?['groupId']?.toString();
    if (payloadId != null && payloadId.isNotEmpty) return payloadId;
    final request = link?['groupRequest'] as Map<String, dynamic>?;
    final directId = request?['groupId']?.toString();
    if (directId != null && directId.isNotEmpty) return directId;
    return (request?['group'] as Map<String, dynamic>?)?['id']?.toString();
  }

  /// The message stored on the embedded group invite request (includes group name).
  String get groupInviteMessage {
    final l = link;
    if (l == null) return message;
    final request =
        (l['groupRequest'] ?? l['request']) as Map<String, dynamic>?;
    if (request == null) return message;
    final req = request['message'] as String?;
    return (req != null && req.isNotEmpty) ? req : message;
  }

  /// The group id embedded in a GROUP_INVITE notification link.
  String? get groupInviteGroupId {
    final payloadId = data?['groupId']?.toString();
    if (payloadId != null && payloadId.isNotEmpty) return payloadId;
    final l = link;
    if (l == null) return linkId;
    final req = (l['groupRequest'] ?? l['request']) as Map<String, dynamic>?;
    if (req == null) return linkId;
    final direct = req['groupId'] as String?;
    if (direct != null) return direct;
    final group = req['group'] as Map<String, dynamic>?;
    return (group?['id'] as String?) ?? linkId;
  }

  /// The group name embedded in a GROUP_INVITE notification link.
  String? get groupInviteGroupName {
    final l = link;
    if (l == null) return null;
    final req = (l['groupRequest'] ?? l['request']) as Map<String, dynamic>?;
    if (req == null) return null;
    final group = req['group'] as Map<String, dynamic>?;
    return group?['name'] as String?;
  }

  /// The message stored on the embedded request (preferred over top-level message).
  String get watchRequestMessage {
    final l = link;
    if (l == null) return message;
    final request = (l['request']) as Map<String, dynamic>?;
    if (request == null) return message;
    final req = request['message'] as String?;
    return (req != null && req.isNotEmpty) ? req : message;
  }

  /// The ID of the embedded request object (used to update it on accept/decline).
  String? get linkedRequestId {
    final payloadPlanId = data?['watchPlanId']?.toString() ??
        data?['watchRequestId']?.toString() ??
        data?['requestId']?.toString();
    if (payloadPlanId != null && payloadPlanId.isNotEmpty) return payloadPlanId;
    final l = link;
    if (l == null) return relatedId;
    final request =
        (l['request'] ?? l['groupRequest']) as Map<String, dynamic>?;
    return request?['id'] as String? ?? relatedId;
  }

  factory FlixieNotification.fromJson(Map<String, dynamic> json) {
    return FlixieNotification(
      id: json['id'] as String?,
      userId: json['userId'] as String,
      type: json['type'] as String,
      action: json['action'] as String?,
      event: json['event'] as String? ??
          (json['data'] as Map<String, dynamic>?)?['event']?.toString(),
      message: json['message'] as String? ?? '',
      read: json['read'] as bool? ?? json['isRead'] as bool?,
      closed: json['closed'] as bool?,
      relatedId: json['relatedId'] as String?,
      linkId: json['linkId'] as String?,
      notificationReceived: json['notificationReceived'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      senderUser: (json['data'] as Map<String, dynamic>?)?['sender']
              as Map<String, dynamic>? ??
          json['user'] as Map<String, dynamic>?,
      link: json['link'] as Map<String, dynamic>?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  FlixieNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? action,
    String? event,
    String? message,
    bool? read,
    bool? closed,
    String? relatedId,
    String? linkId,
    String? notificationReceived,
    String? createdAt,
    String? updatedAt,
    Map<String, dynamic>? senderUser,
    Map<String, dynamic>? link,
    Map<String, dynamic>? data,
  }) {
    return FlixieNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      action: action ?? this.action,
      event: event ?? this.event,
      message: message ?? this.message,
      read: read ?? this.read,
      closed: closed ?? this.closed,
      relatedId: relatedId ?? this.relatedId,
      linkId: linkId ?? this.linkId,
      notificationReceived: notificationReceived ?? this.notificationReceived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderUser: senderUser ?? this.senderUser,
      link: link ?? this.link,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'action': action,
      'message': message,
      'read': read,
      'closed': closed,
      'relatedId': relatedId,
      'linkId': linkId,
      'notificationReceived': notificationReceived,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'data': data,
    };
  }
}
