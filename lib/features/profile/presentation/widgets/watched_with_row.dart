import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import 'package:flixie_app/models/friendship.dart';
import 'profile_avatar_view.dart';

class WatchedWithRow extends StatelessWidget {
  const WatchedWithRow(
      {super.key,
      this.companion,
      this.companions = const [],
      this.viewerUserId});
  final FriendshipUser? companion;
  final List<FriendshipUser> companions;
  final String? viewerUserId;

  @override
  Widget build(BuildContext context) {
    final viewer = viewerUserId ?? context.watch<AuthProvider?>()?.dbUser?.id;
    final people = companions.isNotEmpty
        ? companions
        : [if (companion != null) companion!];
    if (people.isEmpty) return const SizedBox.shrink();
    final names = people
        .map((person) => person.id == viewer ? 'you' : person.displayName)
        .toList();
    final label = names.length == 1
        ? names.single
        : '${names.take(names.length - 1).join(', ')} and ${names.last}';
    Widget avatar(FriendshipUser person) => SizedBox(
        width: 36,
        height: 36,
        child: Center(
            child: ProfileAvatarView(
                avatar: person.avatar,
                profileBadges: person.profileBadges,
                fallbackText: person.displayName,
                fallbackColor: avatarColorFromIconColor(person.iconColor),
                size: 26)));
    final text = Text('Watched with $label',
        style: TextStyle(color: context.colors.light, fontSize: 13));
    if (people.length == 1) {
      return Row(children: [
        avatar(people.single),
        const SizedBox(width: 6),
        Expanded(child: text)
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 4, runSpacing: 4, children: people.map(avatar).toList()),
      const SizedBox(height: 4),
      text,
    ]);
  }
}
