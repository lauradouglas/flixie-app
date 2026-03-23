class Friend {
  final String? id;
  final String userId;
  final String friendId;
  final String? status;
  final String? createdAt;

  const Friend({
    this.id,
    required this.userId,
    required this.friendId,
    this.status,
    this.createdAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] as String?,
      userId: json['userId'] as String,
      friendId: json['friendId'] as String,
      status: json['status'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'friendId': friendId,
      'status': status,
      'createdAt': createdAt,
    };
  }
}

class FriendRequest {
  final String? id;
  final String senderId;
  final String receiverId;
  final String? status;
  final String? type;
  final int? mediaId;
  final String? mediaType;
  final String? createdAt;
  final String? updatedAt;

  const FriendRequest({
    this.id,
    required this.senderId,
    required this.receiverId,
    this.status,
    this.type,
    this.mediaId,
    this.mediaType,
    this.createdAt,
    this.updatedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String?,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      status: json['status'] as String?,
      type: json['type'] as String?,
      mediaId: json['mediaId'] as int?,
      mediaType: json['mediaType'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status,
      'type': type,
      'mediaId': mediaId,
      'mediaType': mediaType,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
