class WatchRequestUser {
  final String id;
  final String username;
  final String? firstName;
  final String? lastName;
  final Map<String, dynamic>? iconColor;

  const WatchRequestUser({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.iconColor,
  });

  factory WatchRequestUser.fromJson(Map<String, dynamic> json) {
    return WatchRequestUser(
      id: json['id'] as String,
      username: json['username'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      iconColor: json['iconColor'] as Map<String, dynamic>?,
    );
  }

  String get displayName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : username;
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
      id: json['id'] as int,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
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
  final WatchRequestUser? requester;
  final WatchRequestUser? recipient;
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
    this.requester,
    this.recipient,
    this.movie,
  });

  factory WatchRequest.fromJson(Map<String, dynamic> json) {
    return WatchRequest(
      id: json['id'] as String,
      requesterId: json['requesterId'] as String,
      recipientId: json['recipientId'] as String,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      response: json['response'] as String?,
      movieId: json['movieId'] as int?,
      type: json['type'] as String? ?? 'MOVIE_WATCH_REQUEST',
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      requester: json['requester'] != null
          ? WatchRequestUser.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      recipient: json['recipient'] != null
          ? WatchRequestUser.fromJson(json['recipient'] as Map<String, dynamic>)
          : null,
      movie: json['movie'] != null
          ? WatchRequestMovieDetails.fromJson(
              json['movie'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Returns the other user (not the current user) in this request.
  WatchRequestUser? otherUser(String myUserId) {
    return requesterId == myUserId ? recipient : requester;
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isDeclined => status == 'DECLINED';
}
