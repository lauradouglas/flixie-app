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
    required this.sentAt,
    this.avatar,
    this.initials,
    this.profileBadges = const [],
    this.replyTo,
    this.onLongPress,
  });

  final String message;
  final String senderUsername;
  final bool isMe;
  final DateTime sentAt;
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
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
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
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 4),
                child: Text(
                  senderUsername,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 12,
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
                    size: 36,
                    profileBadges: profileBadges,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.62,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? FlixieColors.primary : FlixieColors.surface,
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
                        color: isMe ? Colors.white : FlixieColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timeLabel(sentAt),
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
