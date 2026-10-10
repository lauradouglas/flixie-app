import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/group_insights.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class GroupInsightWatchers extends StatelessWidget {
  const GroupInsightWatchers({super.key, required this.watchers});
  final List<GroupInsightUser> watchers;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final watcher in watchers.take(4))
            ProfileAvatarView(
              avatar: watcher.avatar ?? _legacyAvatar(watcher.avatarUrl),
              profileBadges: watcher.profileBadges,
              fallbackText: watcher.username.trim().isEmpty
                  ? '?'
                  : watcher.username.trim().characters.first,
              fallbackColor: FlixieColors.primary,
              size: 26,
            ),
          if (watchers.length > 4)
            Text(
              '+${watchers.length - 4}',
              style: TextStyle(color: context.colors.medium),
            ),
        ],
      );

  ProfileAvatar? _legacyAvatar(String? url) =>
      url == null || !(url.startsWith('https://') || url.startsWith('http://'))
          ? null
          : ProfileAvatar(
              id: 0,
              key: 'insight-url',
              displayName: '',
              storagePath: '',
              imageUrl: url,
            );
}
