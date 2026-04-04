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

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderUsername,
    required this.text,
    required this.createdAt,
    this.replyToMessageId,
    this.imageUrl,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderUsername: data['senderUsername'] as String?,
      text: data['text'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToMessageId: data['replyToMessageId'] as String?,
      imageUrl: data['imageUrl'] as String?,
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
      memberIds:
          (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate(),
      name: data['name'] as String?,
      pgGroupId: data['pgGroupId'] as String?,
    );
  }

  factory Conversation.fromMap(Map<String, dynamic> data) {
    return Conversation(
      id: data['id'] as String? ?? '',
      type: data['type'] as String? ?? 'group',
      memberIds:
          (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] != null
          ? DateTime.tryParse(data['lastMessageAt'].toString())
          : null,
      name: data['name'] as String?,
      pgGroupId: data['pgGroupId'] as String?,
    );
  }
}
