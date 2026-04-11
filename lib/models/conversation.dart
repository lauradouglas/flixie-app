import 'package:cloud_firestore/cloud_firestore.dart';

/// A message inside a Firestore conversation subcollection.
class ChatMessage {
  final String id;
  final String senderId;
  final String? senderUsername;
  final String text;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? imageUrl;

  /// Message type: 'text' | 'watch_request' | 'system'
  final String type;

  /// The Postgres watch-request ID, present when [type] == 'watch_request'.
  final String? watchRequestId;

  /// Snapshot of watch-request info embedded by the backend when the message
  /// was created. Keys: movieTitle, moviePosterPath, message, requesterUsername.
  final Map<String, dynamic>? watchRequestPayload;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderUsername,
    required this.text,
    required this.createdAt,
    this.replyToMessageId,
    this.imageUrl,
    this.type = 'text',
    this.watchRequestId,
    this.watchRequestPayload,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final type = data['type'] as String? ?? 'text';

    // For watch_request messages the backend may store the data at the top
    // level rather than nested under a 'watchRequest' key.
    Map<String, dynamic>? payload =
        data['watchRequest'] as Map<String, dynamic>?;
    if (payload == null && type == 'watch_request') {
      payload = Map<String, dynamic>.from(data);
    }

    // expiresAt may be a Firestore Timestamp — convert to ISO string
    final rawExpires = payload?['expiresAt'];
    if (rawExpires is Timestamp && payload != null) {
      payload = Map<String, dynamic>.from(payload)
        ..['expiresAt'] = rawExpires.toDate().toIso8601String();
    }

    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? data['createdBy']) as String? ?? '',
      senderUsername: data['senderUsername'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToMessageId: data['replyToMessageId'] as String?,
      imageUrl: data['imageUrl'] as String?,
      type: type,
      watchRequestId: (data['watchRequestId'] ??
          (data['metadata'] as Map<String, dynamic>?)?['watchRequestId'] ??
          (data['watchRequest'] as Map<String, dynamic>?)?['id'] ??
          data['pgGroupRequestId'] ??
          data['requestId']) as String?,
      watchRequestPayload: payload,
    );
  }
}

/// A Firestore conversation document (direct or group).
class Conversation {
  final String id;
  final String type; // 'direct' | 'group'
  final List<String> memberIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? name;
  final String? pgGroupId; // links to Prisma group id

  const Conversation({
    required this.id,
    required this.type,
    required this.memberIds,
    this.lastMessage,
    this.lastMessageAt,
    this.name,
    this.pgGroupId,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Conversation(
      id: doc.id,
      type: data['type'] as String? ?? 'group',
      memberIds: (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      name: data['name'] as String?,
      pgGroupId: data['pgGroupId'] as String?,
    );
  }

  factory Conversation.fromMap(Map<String, dynamic> data) {
    return Conversation(
      id: data['id'] as String? ?? '',
      type: data['type'] as String? ?? 'group',
      memberIds: (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] != null
          ? DateTime.tryParse(data['lastMessageAt'].toString())
          : null,
      name: data['name'] as String?,
      pgGroupId: data['pgGroupId'] as String?,
    );
  }
}
