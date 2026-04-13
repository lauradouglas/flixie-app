import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.senderUsername,
    required this.isMe,
    this.replyTo,
  });

  final String message;
  final String senderUsername;
  final bool isMe;
  final String? replyTo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (replyTo != null)
            Padding(
              padding: EdgeInsets.only(
                  left: isMe ? 0 : 4, right: isMe ? 4 : 0, bottom: 2),
              child: Text(replyTo!,
                  style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 10,
                      fontStyle: FontStyle.italic)),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 4,
              right: isMe ? 4 : 0,
              bottom: 3,
            ),
            child: Text(
              isMe ? 'You' : senderUsername,
              style: TextStyle(
                color: isMe
                    ? FlixieColors.primary.withValues(alpha: 0.8)
                    : FlixieColors.medium,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? FlixieColors.primary.withValues(alpha: 0.85)
                  : FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.black : FlixieColors.light,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
