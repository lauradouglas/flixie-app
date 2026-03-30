import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'edit_profile_sheet.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.bio,
    this.iconColor,
  });

  final String displayName;
  final String email;
  final String? photoUrl;
  final String? bio;
  final Map<String, dynamic>? iconColor;

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
        currentUsername: displayName,
        currentBio: bio,
      ),
    );
  }

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
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlixieColors.secondary,
                    FlixieColors.secondaryTint,
                    FlixieColors.secondaryShade,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: color.withValues(alpha: 0.75),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl!) : null,
                    child: photoUrl == null
                        ? Icon(Icons.person,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.70))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _openEditSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FlixieColors.tabBarBackgroundFocused,
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.edit,
                            size: 14, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(
            height: 56), // accounts for avatar overlap (48 radius + 8 padding)
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
