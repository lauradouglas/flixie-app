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
    this.onPreview,
    this.bio,
    this.iconColor,
    this.avatar,
    this.profileBadges = const [],
  });

  final String displayName;
  final String username;
  final String? memberSince;
  final VoidCallback? onPreview;
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
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
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
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: FlixieColors.background,
        builder: (_) => const FractionallySizedBox(
          heightFactor: .9,
          child: ChangeAvatarSheet(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _avatarColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _openAvatarSheet(context),
            child: ProfileAvatarView(
              avatar: avatar,
              fallbackText:
                  displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
              fallbackColor: color,
              size: 108,
              profileBadges: profileBadges,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final badgesInline =
                    profileBadges.isNotEmpty && constraints.maxWidth >= 240;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FlixieColors.light,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgesInline) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ProfileBadgePills(
                                badges: profileBadges,
                                compact: true,
                                featuredOnly: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (profileBadges.isNotEmpty && !badgesInline) ...[
                      const SizedBox(height: 8),
                      ProfileBadgePills(
                        badges: profileBadges,
                        compact: true,
                        featuredOnly: true,
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        color: FlixieColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (bio case final bioText
                        when bioText != null && bioText.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        bioText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ProfileHeaderAction(
                          icon: Icons.edit_rounded,
                          label: 'Edit',
                          onTap: () => _openEditSheet(context),
                        ),
                        if (onPreview != null) ...[
                          const SizedBox(width: 22),
                          _ProfileHeaderAction(
                            icon: Icons.visibility_outlined,
                            label: 'Preview',
                            onTap: onPreview!,
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderAction extends StatelessWidget {
  const _ProfileHeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: FlixieColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: FlixieColors.tabBarBorder),
            ),
            child: Icon(icon, color: FlixieColors.light, size: 18),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: FlixieColors.medium, fontSize: 12)),
        ],
      ),
    );
  }
}
