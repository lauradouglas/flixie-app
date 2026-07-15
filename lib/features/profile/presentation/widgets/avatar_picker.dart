import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.avatars,
    required this.selectedId,
    required this.onSelected,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final List<ProfileAvatar> avatars;
  final int? selectedId;
  final ValueChanged<ProfileAvatar> onSelected;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null || avatars.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error ?? 'No profile avatars are currently available.'),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final selected = avatar.id == selectedId;
        return Semantics(
          button: true,
          selected: selected,
          label: '${avatar.displayName}${selected ? ', selected' : ''}',
          child: InkWell(
            onTap: () => onSelected(avatar),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FlixieColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? FlixieColors.primary
                      : FlixieColors.tabBarBorder,
                  width: selected ? 3 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ProfileAvatarView(
                    avatar: avatar,
                    fallbackText: avatar.displayName.substring(0, 1),
                    fallbackColor: FlixieColors.primary,
                    size: 64,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
