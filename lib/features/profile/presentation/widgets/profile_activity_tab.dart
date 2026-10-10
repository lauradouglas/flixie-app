import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

import '../../models/profile_section.dart';

class ProfileActivityTab extends StatelessWidget {
  const ProfileActivityTab(
      {super.key,
      required this.activity,
      required this.filter,
      required this.loading,
      required this.failed,
      required this.paging,
      required this.nextCursor,
      required this.onFilterSelected,
      required this.onRetry,
      required this.onLoadMore});
  final List<ActivityListItem> activity;
  final ProfileActivityFilter filter;
  final bool loading, failed, paging;
  final String? nextCursor;
  final ValueChanged<ProfileActivityFilter> onFilterSelected;
  final VoidCallback onRetry, onLoadMore;
  @override
  Widget build(BuildContext context) {
    final visibleActivity = activity;
    final filtered = visibleActivity
        .where((item) => switch (filter) {
              ProfileActivityFilter.all => true,
              ProfileActivityFilter.watches =>
                item.type == ActivityListType.movieWatched ||
                    item.type == ActivityListType.showWatched,
              ProfileActivityFilter.ratings =>
                item.type == ActivityListType.movieRating ||
                    item.type == ActivityListType.showRating,
              ProfileActivityFilter.reviews =>
                item.type == ActivityListType.movieReview ||
                    item.type == ActivityListType.showReview,
              ProfileActivityFilter.lists =>
                item.type == ActivityListType.movieWatchlist ||
                    item.type == ActivityListType.showWatchlist,
            })
        .toList()
      ..sort((a, b) {
        final dates = (DateTime.tryParse(b.timestamp) ?? DateTime(1970))
            .compareTo(DateTime.tryParse(a.timestamp) ?? DateTime(1970));
        return dates != 0
            ? dates
            : '${a.type.value}:${a.id}'.compareTo('${b.type.value}:${b.id}');
      });
    final rows = <Object>[];
    String? lastDate;
    for (final item in filtered.take(activity.length)) {
      final date = _activityDateLabel(item.timestamp);
      if (date != lastDate) {
        rows.add(date);
        lastDate = date;
      }
      rows.add(item);
    }
    return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
      if (index == 0) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your activity',
              style: TextStyle(
                  color: context.colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SingleChildScrollView(
              key: const PageStorageKey('profile-activity-filters'),
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final filter in ProfileActivityFilter.values)
                  Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FlixiePill.choice(
                          selected: filter == this.filter,
                          showCheckmark: false,
                          label: Text(filter == ProfileActivityFilter.lists
                              ? 'Watchlist'
                              : _filterLabel(filter)),
                          onSelected: (_) {
                            onFilterSelected(filter);
                          })),
              ])),
          const SizedBox(height: 12),
          if (loading && activity.isEmpty)
            const ContentPlaceholder(label: 'Loading activity')
          else if (failed)
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Couldn’t load activity · Retry'))
          else
            Text(
                filtered.isEmpty
                    ? 'No activity yet.'
                    : 'Showing ${filtered.take(activity.length).length} activities',
                style: TextStyle(color: context.colors.medium)),
          const SizedBox(height: 12),
        ]);
      }
      if (index == rows.length + 1) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: nextCursor != null
                ? TextButton.icon(
                    onPressed: paging ? null : () => onLoadMore(),
                    icon: const Icon(Icons.expand_more),
                    label: LoadingActionLabel(
                        loading: paging, text: 'Load 20 more'))
                : filtered.isEmpty
                    ? const SizedBox.shrink()
                    : Center(
                        child: Text('You’re up to date',
                            style: TextStyle(color: context.colors.medium))));
      }
      final row = rows[index - 1];
      if (row is String) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(row,
                style: TextStyle(
                    color: context.colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)));
      }
      final item = row as ActivityListItem;
      return ActivityTile(
          key: ValueKey('${item.type.value}:${item.id}'),
          item: item,
          compact: true);
    }, childCount: rows.length + 2));
  }
}

String _filterLabel(ProfileActivityFilter filter) => switch (filter) {
      ProfileActivityFilter.all => 'All',
      ProfileActivityFilter.watches => 'Watches',
      ProfileActivityFilter.ratings => 'Ratings',
      ProfileActivityFilter.reviews => 'Reviews',
      ProfileActivityFilter.lists => 'Lists',
    };

String _activityDateLabel(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return 'Earlier';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final value = DateTime(date.year, date.month, date.day);
  final days = today.difference(value).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days > 1 && days < 7) return '$days days ago';
  return '${date.day} ${const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ][date.month - 1]} ${date.year}';
}
