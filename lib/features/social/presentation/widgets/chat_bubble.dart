import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.senderUsername,
    required this.isMe,
    this.avatar,
    this.initials,
    this.profileBadges = const [],
    this.replyTo,
    this.onLongPress,
  });

  final String message;
  final String senderUsername;
  final bool isMe;
  final ProfileAvatar? avatar;
  final String? initials;
  final List<String> profileBadges;
  final String? replyTo;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
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
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  ProfileAvatarView(
                    avatar: avatar,
                    fallbackText: initials?.isNotEmpty == true
                        ? initials!
                        : senderUsername.isNotEmpty
                            ? senderUsername[0].toUpperCase()
                            : '?',
                    fallbackColor: FlixieColors.primary,
                    size: 30,
                    profileBadges: profileBadges,
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.66,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          ],
        ),
      ),
    );
  }
}
