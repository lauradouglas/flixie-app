import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'movie_friends_summary_badges.dart';
import 'movie_social_opinions.dart';

enum FriendActivityTab { all, watched, watchlist, ratings, reviews, lists }

class MovieFriendsSection extends StatelessWidget {
  const MovieFriendsSection(
      {super.key,
      required this.movieId,
      required this.activities,
      required this.signedIn,
      required this.loading,
      required this.summaryLoaded,
      required this.hasSummary,
      required this.hasError,
      required this.onReload});
  final int movieId;
  final List<MovieFriendActivity> activities;
  final bool signedIn;
  final bool loading;
  final bool summaryLoaded;
  final bool hasSummary;
  final bool hasError;
  final VoidCallback onReload;
  @override
  Widget build(BuildContext context) {
    if (!signedIn) return const SizedBox.shrink();
    if (loading && activities.isEmpty && !summaryLoaded) {
      return const ContentPlaceholder(
          label: 'Loading friend activity', rows: 1);
    }
    if (activities.isEmpty && hasSummary) {
      return const SizedBox.shrink();
    }
    if (activities.isEmpty && hasError) {
      return TextButton.icon(
        onPressed: onReload,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Reload friend activity'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Friends',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (activities.isNotEmpty)
              TextButton.icon(
                onPressed: () => _showAllFriendsActivity(context, activities),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                label: const Text('View all'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primaryText,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        MovieFriendsRatingSummary(activities: activities, movieId: movieId),
        const SizedBox(height: 12),
        ...activities
            .take(5)
            .map((activity) => _compactFriendRow(context, activity)),
      ],
    );
  }

  BoxDecoration _friendPanelDecoration(BuildContext context) => BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      );

  Widget _buildFriendsSummaryPanel(
          BuildContext context, List<MovieFriendActivity> activities) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: _friendPanelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Friends summary',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width:
                        38 + (activities.take(3).length - 1).clamp(0, 2) * 22.0,
                    height: 38,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: activities
                          .take(3)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => Positioned(
                              left: entry.key * 22.0,
                              child: _compactFriendAvatar(context, entry.value,
                                  size: 38),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                MovieFriendsSummaryBadges(
                    activities: activities, movieId: movieId),
              ],
            ),
          ],
        ),
      );

  Widget _compactFriendAvatar(
      BuildContext context, MovieFriendActivity activity,
      {double size = 30}) {
    final hex =
        activity.iconColor?['hexCode']?.toString().replaceFirst('#', '');
    final value = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    final color = value == null ? FlixieColors.primary : Color(value);
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: context.colors.surface,
        shape: BoxShape.circle,
      ),
      child: ProfileAvatarView(
        avatar: activity.avatar,
        fallbackText: activity.username.isEmpty
            ? '?'
            : activity.username[0].toUpperCase(),
        fallbackColor: color,
        size: size - 3,
        profileBadges: activity.profileBadges,
      ),
    );
  }

  Widget _compactFriendRow(
          BuildContext context, MovieFriendActivity activity) =>
      MovieFriendOpinionRow(
          movieId: movieId,
          activity: activity,
          onTap: () => context.push('/friends/${activity.userId}'));

  Future<void> _showAllFriendsActivity(
    BuildContext context,
    List<MovieFriendActivity> activities,
  ) {
    var selectedTab = FriendActivityTab.all;
    var query = '';
    final watchedCount = activities.where((item) => item.watched).length;
    final ratedCount = activities.where((item) => item.rating != null).length;
    final recommendCount =
        activities.where((item) => item.recommended == true).length;
    final watchlistCount = activities.where((item) => item.onWatchlist).length;

    return showModalBottomSheet<void>(
      useRootNavigator: true,
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final visible = activities.where((activity) {
            final matchesQuery = query.isEmpty ||
                activity.username.toLowerCase().contains(query);
            final matchesTab = switch (selectedTab) {
              FriendActivityTab.all => true,
              FriendActivityTab.watched => activity.watched,
              FriendActivityTab.watchlist => activity.onWatchlist,
              FriendActivityTab.ratings => activity.rating != null,
              FriendActivityTab.reviews => activity.recommended == true,
              FriendActivityTab.lists => true,
            };
            return matchesQuery && matchesTab;
          }).toList(growable: false);
          final tabs = <(FriendActivityTab, String, int)>[
            (FriendActivityTab.all, 'All', activities.length),
            (FriendActivityTab.watched, 'Watched', watchedCount),
            (FriendActivityTab.ratings, 'Rated', ratedCount),
            (FriendActivityTab.reviews, 'Recommend', recommendCount),
            (FriendActivityTab.watchlist, 'Watchlist', watchlistCount),
          ];

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            expand: false,
            builder: (context, controller) => Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.colors.medium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Friends',
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${activities.length} ${activities.length == 1 ? 'friend' : 'friends'} interacted with this movie',
                        style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _buildFriendsSummaryPanel(context, activities),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      onChanged: (value) => setSheetState(
                        () => query = value.trim().toLowerCase(),
                      ),
                      style: TextStyle(color: context.colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search friends',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor:
                            context.colors.background.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: tabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (_, index) {
                        final tab = tabs[index];
                        final selected = selectedTab == tab.$1;
                        return FlixiePill.choice(
                            selected: selected,
                            showCheckmark: false,
                            label: Text('${tab.$2}  ${tab.$3}'),
                            onSelected: (_) =>
                                setSheetState(() => selectedTab = tab.$1));
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: context.colors.tabBarBorder),
                  Expanded(
                    child: visible.isEmpty
                        ? Center(
                            child: Text('No matching friends',
                                style: TextStyle(color: context.colors.medium)),
                          )
                        : ListView.builder(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                            itemCount: visible.length,
                            itemBuilder: (_, index) =>
                                _compactFriendRow(context, visible[index]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
