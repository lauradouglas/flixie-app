class FlixieNotification {
  final String? id;
  final String userId;
  final String type;
  final String message;
  final bool? isRead;
  final String? relatedId;
  final String? createdAt;
  final String? updatedAt;

  const FlixieNotification({
    this.id,
    required this.userId,
    required this.type,
    required this.message,
    this.isRead,
    this.relatedId,
    this.createdAt,
    this.updatedAt,
  });

  factory FlixieNotification.fromJson(Map<String, dynamic> json) {
    return FlixieNotification(
      id: json['id'] as String?,
      userId: json['userId'] as String,
      type: json['type'] as String,
      message: json['message'] as String,
      isRead: json['isRead'] as bool?,
      relatedId: json['relatedId'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'message': message,
      'isRead': isRead,
      'relatedId': relatedId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
