import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_avatar.dart';

class RecipientOptionTile extends StatelessWidget {
  const RecipientOptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.group = false,
    this.avatar,
    this.avatarColor = FlixieColors.primary,
    this.groupModel,
    this.profileBadges = const [],
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool group;
  final ProfileAvatar? avatar;
  final Color avatarColor;
  final Group? groupModel;
  final List<String> profileBadges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? FlixieColors.primary.withValues(alpha: 0.16)
                : context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? FlixieColors.primary : context.colors.tabBarBorder,
            ),
          ),
          child: Row(
            children: [
              if (group && groupModel != null)
                GroupAvatar(group: groupModel!, radius: 18)
              else if (!group)
                ProfileAvatarView(
                  avatar: avatar,
                  profileBadges: profileBadges,
                  fallbackText: title.isEmpty ? '?' : title[0].toUpperCase(),
                  fallbackColor: avatarColor,
                  size: 36,
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      size: 20, color: avatarColor),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.colors.light,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle?.isNotEmpty == true)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? const Icon(Icons.check_circle_rounded,
                        key: ValueKey('selected'),
                        color: FlixieColors.primary,
                        size: 22)
                    : Icon(Icons.circle_outlined,
                        key: const ValueKey('unselected'),
                        color: context.colors.medium,
                        size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
