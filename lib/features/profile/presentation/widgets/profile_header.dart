import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.email,
    this.photoUrl,
    this.bio,
    this.iconColor,
    this.avatar,
  });

  final String displayName;
  final String username;
  final String email;
  final String? photoUrl;
  final String? bio;
  final Map<String, dynamic>? iconColor;
  final ProfileAvatar? avatar;

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
    return Column(
      children: [
        // Banner with avatar overlaid using Stack
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 130,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B3A70),
                    FlixieColors.secondary,
                    FlixieColors.primary,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Subtle pattern overlay
                  Opacity(
                    opacity: 0.06,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0.8, -0.6),
                          radius: 1.2,
                          colors: [Colors.white, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -52,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      FlixieColors.primary.withValues(alpha: 0.6),
                      FlixieColors.secondary.withValues(alpha: 0.4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: FlixieColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: () => _openAvatarSheet(context),
                  child: ProfileAvatarView(
                    avatar: avatar,
                    fallbackText: displayName.isEmpty
                        ? '?'
                        : displayName[0].toUpperCase(),
                    fallbackColor: color,
                    size: 96,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
            height: 62), // accounts for avatar overlap (48 radius + 14 padding)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayName, style: textTheme.headlineMedium),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openEditSheet(context),
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: FlixieColors.medium,
              ),
            ),
          ],
        ),
        if (email.isNotEmpty) Text(email, style: textTheme.bodySmall),
        if (bio case final bioText
            when bioText != null && bioText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              bioText,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
