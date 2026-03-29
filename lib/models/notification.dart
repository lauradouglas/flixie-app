class FlixieNotification {
  // Notification type constants
  static const String friendRequest = 'FRIEND_REQUEST';
  static const String groupRequest = 'GROUP_REQUEST';
  static const String groupInvite = 'GROUP_INVITE';
  static const String movieWatchRequest = 'MOVIE_WATCH_REQUEST';
  static const String showWatchRequest = 'SHOW_WATCH_REQUEST';

  // Notification action constants
  static const String actionSent = 'SENT';
  static const String actionReceived = 'RECEIVED';
  static const String actionAccepted = 'ACCEPTED';
  static const String actionDeclined = 'DECLINED';

  final String? id;
  final String userId;
  final String type;
  final String? action;
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

  const FlixieNotification({
    this.id,
    required this.userId,
    required this.type,
    this.action,
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

  factory FlixieNotification.fromJson(Map<String, dynamic> json) {
    return FlixieNotification(
      id: json['id'] as String?,
      userId: json['userId'] as String,
      type: json['type'] as String,
      action: json['action'] as String?,
      message: json['message'] as String? ?? '',
      read: json['read'] as bool? ?? json['isRead'] as bool?,
      closed: json['closed'] as bool?,
      relatedId: json['relatedId'] as String?,
      linkId: json['linkId'] as String?,
      notificationReceived: json['notificationReceived'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      senderUser: json['user'] as Map<String, dynamic>?,
      link: json['link'] as Map<String, dynamic>?,
    );
  }

  FlixieNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? action,
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
  }) {
    return FlixieNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      action: action ?? this.action,
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
    };
  }
}
