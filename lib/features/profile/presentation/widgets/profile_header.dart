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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _openAvatarSheet(context),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ProfileAvatarView(
                        avatar: avatar,
                        fallbackText: displayName.isEmpty
                            ? '?'
                            : displayName[0].toUpperCase(),
                        fallbackColor: color,
                        size: 88,
                        profileBadges: profileBadges,
                      ),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: FlixieColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineSmall?.copyWith(
                          color: FlixieColors.light,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (profileBadges.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        ProfileBadgePills(
                          badges: profileBadges,
                          compact: true,
                          featuredOnly: true,
                        ),
                      ],
                      if (displayName.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          displayName,
                          style: textTheme.bodyLarge?.copyWith(
                            color: FlixieColors.light,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (memberSince != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          memberSince!,
                          style: textTheme.bodySmall?.copyWith(
                            color: FlixieColors.medium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (bio case final bioText
                when bioText != null && bioText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                bioText,
                style: textTheme.bodyMedium?.copyWith(
                  color: FlixieColors.light,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openEditSheet(context),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit profile'),
                  ),
                ),
                if (onPreview != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('Preview'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
