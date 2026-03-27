/// Lightweight user info embedded in friendship/friend-request objects.
class FriendshipUser {
  final String id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? initials;
  final Map<String, dynamic>? iconColor;

  const FriendshipUser({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.initials,
    this.iconColor,
  });

  factory FriendshipUser.fromJson(Map<String, dynamic> json) {
    return FriendshipUser(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      initials: json['initials'] as String?,
      iconColor: json['iconColor'] as Map<String, dynamic>?,
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '${firstName!} ${lastName!}';
    }
    return username;
  }

  String get shortName {
    if (firstName != null && lastName != null) {
      return '${firstName!} ${lastName![0]}.';
    }
    return username;
  }
}

/// A confirmed friendship between two users.
class Friendship {
  final int id;
  final int? friendId;
  final FriendshipUser? friend;
  final FriendshipUser? recipient;
  final FriendshipUser? requester;
  final String createdAt;
  final String updatedAt;

  const Friendship({
    required this.id,
    this.friendId,
    this.friend,
    this.recipient,
    this.requester,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: (json['id'] as num).toInt(),
      friendId: (json['friendId'] as num?)?.toInt(),
      friend: json['friend'] != null
          ? FriendshipUser.fromJson(json['friend'] as Map<String, dynamic>)
          : null,
      recipient: json['recipient'] != null
          ? FriendshipUser.fromJson(json['recipient'] as Map<String, dynamic>)
          : null,
      requester: json['requester'] != null
          ? FriendshipUser.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  /// Returns the friend's user, regardless of which side they are on.
  FriendshipUser? get friendUser => friend ?? recipient ?? requester;
}

/// A pending or outgoing friend request between two users.
class FriendRelationship {
  final int id;
  final int? senderId;
  final FriendshipUser? sender;
  final int? receiverId;
  final FriendshipUser? receiver;
  final String createdAt;
  final String updatedAt;

  const FriendRelationship({
    required this.id,
    this.senderId,
    this.sender,
    this.receiverId,
    this.receiver,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FriendRelationship.fromJson(Map<String, dynamic> json) {
    return FriendRelationship(
      id: (json['id'] as num).toInt(),
      senderId: (json['senderId'] as num?)?.toInt(),
      sender: json['sender'] != null
          ? FriendshipUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      receiverId: (json['receiverId'] as num?)?.toInt(),
      receiver: json['receiver'] != null
          ? FriendshipUser.fromJson(json['receiver'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// The combined friends response returned by GET /friends/:userId
class FriendsData {
  final List<Friendship> friendships;
  final List<FriendRelationship> pendingFriends;
  final List<FriendRelationship> requestedFriends;

  const FriendsData({
    required this.friendships,
    required this.pendingFriends,
    required this.requestedFriends,
  });

  factory FriendsData.fromJson(Map<String, dynamic> json) {
    return FriendsData(
      friendships: (json['friendships'] as List<dynamic>? ?? [])
          .map((e) => Friendship.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingFriends: (json['pendingFriends'] as List<dynamic>? ?? [])
          .map((e) => FriendRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
      requestedFriends: (json['requestedFriends'] as List<dynamic>? ?? [])
          .map((e) => FriendRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  int get totalCount =>
      friendships.length + pendingFriends.length + requestedFriends.length;
}
