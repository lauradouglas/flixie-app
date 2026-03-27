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
  });

  final String displayName;
  final String email;
  final String? photoUrl;
  final String? bio;

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
    return Column(
      children: [
        const SizedBox(height: 16),
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: FlixieColors.primary.withValues(alpha: 0.3),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 48, color: FlixieColors.primary)
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
                    color: FlixieColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FlixieColors.tabBarBackgroundFocused,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        if (email.isNotEmpty)
          Text(email, style: textTheme.bodySmall),
        if (bio != null && bio!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              bio!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
