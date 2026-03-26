import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  final String displayName;
  final String email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 48,
          backgroundColor: FlixieColors.primary.withValues(alpha: 0.3),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? const Icon(Icons.person, size: 48, color: FlixieColors.primary)
              : null,
        ),
        const SizedBox(height: 12),
        Text(displayName, style: textTheme.headlineMedium),
        if (email.isNotEmpty)
          Text(email, style: textTheme.bodySmall),
      ],
    );
  }
}
