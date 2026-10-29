import 'profile_milestone_badges.dart';
import 'expandable_profile_bio.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.username,
    this.memberSince,
    this.userId,
    this.onPreview,
    this.onPeople,
    this.bio,
    this.iconColor,
    this.avatar,
    this.profileBadges = const [],
  });

  final String? userId;
  final String displayName;
  final String username;
  final String? memberSince;
  final VoidCallback? onPreview;
  final VoidCallback? onPeople;
  final String? bio;
  final Map<String, dynamic>? iconColor;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;

  Color get _avatarColor {
    final hex = ((iconColor?['hexCode'] ?? iconColor?['hex']) as String? ?? '')
        .replaceAll('#', '');
    if (hex.isEmpty) return FlixieColors.primary;
    return Color(int.tryParse('0xFF$hex') ?? FlixieColors.primary.toARGB32());
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: context.colors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditProfileSheet(
        currentUsername: username,
        currentBio: bio,
      ),
    );
  }

  void _openAvatarSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        enableDrag: false,
        isDismissible: false,
        useSafeArea: true,
        backgroundColor: context.colors.background,
        builder: (_) => const FractionallySizedBox(
          heightFactor: .9,
          child: ChangeAvatarSheet(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Semantics(
              button: true,
              label: 'Change profile avatar',
              child: InkWell(
                  onTap: () => _openAvatarSheet(context),
                  child: Stack(children: [
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: ProfileAvatarView(
                            avatar: avatar,
                            fallbackText: displayName.isEmpty
                                ? '?'
                                : displayName[0].toUpperCase(),
                            fallbackColor: _avatarColor,
                            size: 80,
                            profileBadges: profileBadges)),
                    Positioned(
                        right: 0,
                        bottom: 0,
                        child: ExcludeSemantics(
                            child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                    color: context.colors.background,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.edit_outlined,
                                    size: 18, color: FlixieColors.primary)))),
                  ]))),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(displayName,
                    style: TextStyle(
                        color: context.colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('@$username',
                    style:
                        TextStyle(color: context.colors.light, fontSize: 13)),
              ])),
        ]),
        if (profileBadges.isNotEmpty && userId == null) ...[
          const SizedBox(height: 12),
          ProfileBadgePills(badges: profileBadges, compact: true),
        ],
        if (userId != null) ...[
          const SizedBox(height: 12),
          ProfileMilestoneBadges(
              key: ValueKey(userId),
              userId: userId!,
              editable: true,
              identityBadges: profileBadges.isEmpty
                  ? null
                  : ProfileBadgePills(badges: profileBadges, compact: true)),
        ],
        if (bio?.isNotEmpty == true) ...[
          SizedBox(height: userId == null ? 12 : 4),
          ExpandableProfileBio(text: bio!),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final stacked = box.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final actions = [
            TextButton.icon(
                onPressed: () => _openEditSheet(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text('Edit profile',
                    style: TextStyle(fontSize: 13, color: context.colors.light))),
            if (onPreview != null)
              TextButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text('Preview profile',
                      style: TextStyle(
                          fontSize: 13, color: context.colors.light))),
          ];
          return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14)),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: actions)
                  : IntrinsicHeight(
                      child: Row(children: [
                      Expanded(child: actions.first),
                      if (actions.length > 1) ...[
                        VerticalDivider(
                            width: 1,
                            indent: 12,
                            endIndent: 12,
                            color: context.colors.tabBarBorder),
                        Expanded(child: actions.last),
                      ],
                    ])));
        }),
        if (onPeople != null) ...[
          const SizedBox(height: 16),
          Material(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                  onTap: onPeople,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(Icons.people_outline,
                            color: context.colors.primaryText, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Friends',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.white))),
                        Icon(Icons.chevron_right,
                            color: context.colors.light, size: 22),
                      ])))),
        ],
      ]),
    );
  }
}
