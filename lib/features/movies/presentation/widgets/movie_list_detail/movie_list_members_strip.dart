import 'package:flutter/material.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class MovieListMembersStrip extends StatelessWidget {
  const MovieListMembersStrip({
    super.key,
    required this.membership,
    required this.onTap,
  });

  final MovieListMembership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = membership.members.take(5).toList(growable: false);
    final contributorCount = membership.scope == ListScope.group
        ? membership.members.length
        : (membership.members.length - 1).clamp(0, membership.members.length);
    final everyoneCanAdd = membership.scope == ListScope.group ||
        membership.whoCanAddItems.toLowerCase() == 'everyone';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: FlixieColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34 + (preview.length - 1) * 20,
                height: 34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < preview.length; index++)
                      Positioned(
                        left: 2 + index * 20,
                        top: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FlixieColors.primary,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(1),
                          child: ProfileAvatarView(
                            avatar: preview[index].avatar,
                            fallbackText: preview[index].username.isEmpty
                                ? '?'
                                : preview[index].username[0].toUpperCase(),
                            fallbackColor: FlixieColors.primary,
                            size: 28,
                            profileBadges: preview[index].profileBadges,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.scope == 'GROUP'
                          ? '${membership.groupName ?? 'Group'} · ${membership.members.length} members'
                          : contributorCount == 0
                              ? 'Only you can edit this list'
                              : '$contributorCount contributor${contributorCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: context.colors.light,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      everyoneCanAdd
                          ? membership.scope == ListScope.group
                              ? 'Every group member can add titles'
                              : 'Everyone can add titles'
                          : 'Only the owner can edit this list',
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: FlixieColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
