import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../pages/community_space_screen.dart' show communityRelativeTime;

class DiscussionAuthor extends StatelessWidget {
  const DiscussionAuthor(
      {super.key,
      required this.row,
      required this.reply,
      required this.currentUserId,
      required this.onAction});
  final Map<String, dynamic> row;
  final bool reply;
  final String? currentUserId;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final user =
        FriendshipUser.fromJson(Map<String, dynamic>.from(row['user']));
    final own = user.id == currentUserId;
    return Row(children: [
      Padding(
          padding: const EdgeInsets.all(4),
          child: ProfileAvatarView(
              avatar: user.avatar,
              profileBadges: user.profileBadges,
              size: 32,
              fallbackColor: context.colors.primary,
              fallbackText: user.username.isEmpty ? '?' : user.username[0])),
      const SizedBox(width: 8),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            user.firstName?.trim().isNotEmpty == true
                ? user.firstName!
                : user.username,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(
            [
              if (DateTime.tryParse(row['createdAt']?.toString() ?? '') != null)
                communityRelativeTime(DateTime.parse(row['createdAt'])),
              if (!reply) 'Started this discussion',
            ].join(' · '),
            style: TextStyle(fontSize: 11, color: context.colors.light)),
      ])),
      PopupMenuButton<String>(
          tooltip: 'Comment options',
          icon: const Icon(Icons.more_horiz),
          itemBuilder: (_) => [
                if (own)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (!own) ...[
                  const PopupMenuItem(
                      value: 'mute', child: Text('Mute author')),
                  const PopupMenuItem(
                      value: 'report', child: Text('Report or block')),
                ]
              ],
          onSelected: onAction),
    ]);
  }
}
