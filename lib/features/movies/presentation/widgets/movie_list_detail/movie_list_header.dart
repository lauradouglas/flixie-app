import 'package:flixie_app/core/widgets/flixie_pill.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';

class MovieListHeader extends StatelessWidget {
  const MovieListHeader({
    super.key,
    required this.listName,
    required this.owner,
    required this.membership,
    required this.canEdit,
    required this.isOwner,
    required this.movieCount,
    required this.posterUrls,
    required this.onAddMovies,
  });

  final String listName;
  final models.User? owner;
  final MovieListMembership? membership;
  final bool canEdit;
  final bool isOwner;
  final int movieCount;
  final List<String> posterUrls;
  final VoidCallback onAddMovies;

  @override
  Widget build(BuildContext context) {
    final isGroupList = membership?.scope == ListScope.group;
    final identity = listIdentity(listName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGroupList)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: membership?.groupId == null
                          ? null
                          : () =>
                              context.push('/groups/${membership!.groupId}'),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.groups_2_rounded,
                                  color: FlixieColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    membership?.groupName ?? 'Group list',
                                    style: TextStyle(
                                      color: context.colors.light,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (membership?.groupId != null)
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: context.colors.medium,
                                    size: 18,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ProfileAvatarView(
                                  avatar: owner?.avatar,
                                  fallbackText: _ownerInitial(owner),
                                  fallbackColor: FlixieColors.primary,
                                  size: 22,
                                  profileBadges:
                                      owner?.profileBadges ?? const [],
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    owner == null
                                        ? visibilityLabel(
                                            membership?.visibility)
                                        : '@${owner!.username} · ${visibilityLabel(membership?.visibility)}',
                                    style: TextStyle(
                                      color: context.colors.medium,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: owner == null
                          ? null
                          : () => context.push(
                                isOwner ? '/profile' : '/friends/${owner!.id}',
                              ),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 3, 8, 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatarView(
                              avatar: owner?.avatar,
                              fallbackText: _ownerInitial(owner),
                              fallbackColor: FlixieColors.primary,
                              size: 34,
                              profileBadges: owner?.profileBadges ?? const [],
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                owner == null
                                    ? visibilityLabel(membership?.visibility)
                                    : '@${owner!.username} · ${visibilityLabel(membership?.visibility)}',
                                style: TextStyle(
                                  color: context.colors.light,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isOwner) ...[
                              const SizedBox(width: 6),
                              const FlixiePill.label(label: Text('Owner')),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  identity.$1,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 28,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (identity.$2 != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    identity.$2!,
                    style: TextStyle(
                      color: context.colors.light,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (membership?.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    membership!.description!.trim(),
                    style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      color: context.colors.medium,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$movieCount ${movieCount == 1 ? 'title' : 'titles'}',
                      style: TextStyle(
                        color: context.colors.medium,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (canEdit) ...[
                  const SizedBox(height: 9),
                  FilledButton.icon(
                    onPressed: onAddMovies,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add titles'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ownerInitial(models.User? user) {
    final username = user?.username.trim() ?? '';
    return username.isEmpty ? '?' : username[0].toUpperCase();
  }
}
