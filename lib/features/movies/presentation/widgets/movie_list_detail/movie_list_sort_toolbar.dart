import 'package:flixie_app/core/widgets/flixie_pill.dart';

import 'package:flutter/material.dart';

import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';

class MovieListSortToolbar extends StatelessWidget {
  const MovieListSortToolbar({
    super.key,
    required this.sort,
    required this.movieCount,
    required this.showCount,
    required this.onSortChanged,
    required this.contributors,
    required this.selectedContributorId,
    required this.onContributorChanged,
  });

  final MovieListSort sort;
  final int movieCount;
  final int showCount;
  final ValueChanged<MovieListSort> onSortChanged;
  final List<MovieListContributor> contributors;
  final String? selectedContributorId;
  final ValueChanged<String?> onContributorChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (sort == MovieListSort.recentlyAdded)
            Text(
              'Recently added',
              style: TextStyle(
                color: context.colors.light,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Text(
              mediaCountLabel(movieCount, showCount),
              style: TextStyle(
                color: context.colors.medium,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          PopupMenuButton<MovieListSort>(
            tooltip: 'Sort list',
            color: context.colors.tabBarBackgroundFocused,
            initialValue: sort,
            onSelected: onSortChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: MovieListSort.recentlyAdded,
                child: Text('Recently added'),
              ),
              PopupMenuItem(
                value: MovieListSort.title,
                child: Text('Title'),
              ),
              PopupMenuItem(
                value: MovieListSort.releaseYear,
                child: Text('Release year'),
              ),
              PopupMenuItem(
                value: MovieListSort.rating,
                child: Text('Rating'),
              ),
              PopupMenuItem(
                value: MovieListSort.addedBy,
                child: Text('Added by'),
              ),
            ],
            child: FlixiePill.label(
                compact: false,
                label: Text(sortLabel(sort)),
                avatar: const Icon(Icons.sort_rounded)),
          ),
          if (contributors.isNotEmpty) ...[
            PopupMenuButton<String>(
              tooltip: 'Filter by contributor',
              color: context.colors.tabBarBackgroundFocused,
              onSelected: (value) =>
                  onContributorChanged(value == '__all__' ? null : value),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: '__all__',
                  child: Row(
                    children: [
                      Icon(
                        selectedContributorId == null
                            ? Icons.check_rounded
                            : Icons.people_outline_rounded,
                        color: FlixieColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(child: Text('Anyone who added titles')),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...contributors.map(
                  (contributor) => PopupMenuItem(
                    value: contributor.id,
                    child: Row(
                      children: [
                        ProfileAvatarView(
                          avatar: contributor.avatar,
                          fallbackText: contributor.username.isEmpty
                              ? '?'
                              : contributor.username[0].toUpperCase(),
                          fallbackColor: FlixieColors.primary,
                          size: 24,
                          profileBadges: contributor.profileBadges,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            contributor.id == selectedContributorId
                                ? '@${contributor.username}  ✓'
                                : '@${contributor.username}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selectedContributorId == null
                      ? context.colors.tabBarBackgroundFocused
                      : FlixieColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selectedContributorId == null
                        ? Colors.white.withValues(alpha: 0.1)
                        : FlixieColors.primary,
                  ),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  color: selectedContributorId == null
                      ? FlixieColors.primary
                      : context.colors.light,
                  size: 20,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
