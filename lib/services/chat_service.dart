import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation.dart';
import 'api_client.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // REST — conversation management
  // ---------------------------------------------------------------------------

  /// Get or create the Firestore conversation linked to a Prisma group.
  static Future<Conversation> getOrCreateGroupConversation({
    required String creatorId,
    required String pgGroupId,
    required String name,
    required List<String> memberIds,
  }) async {
    final data = await ApiClient.post('/conversations/group', body: {
      'creatorId': creatorId,
      'pgGroupId': pgGroupId,
      'name': name,
      'memberIds': memberIds,
    });
    return Conversation.fromMap(data as Map<String, dynamic>);
  }

  /// Send a text message (backend writes to Firestore).
  static Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? replyToMessageId,
  }) async {
    await ApiClient.post('/conversations/$conversationId/messages', body: {
      'senderId': senderId,
      'text': text,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    });
  }

  /// Mark a conversation as read for the given user.
  static Future<void> markRead(
      String conversationId, String userId) async {
    await ApiClient.patch(
      '/conversations/$conversationId/read',
      body: {'userId': userId},
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore — real-time streams
  // ---------------------------------------------------------------------------

  /// Real-time stream of messages (newest-first, capped at 50).
  static Stream<List<ChatMessage>> messagesStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  /// Real-time unread count for a user in a conversation.
  static Stream<int> unreadCountStream(
      String conversationId, String userId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('members')
        .doc(userId)
        .snapshots()
        .map((s) => (s.data()?['unreadCount'] as int?) ?? 0);
  }
}
