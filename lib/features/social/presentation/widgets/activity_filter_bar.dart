import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';

enum ActivityFeedFilter {
  all('All'),
  watched('Watched'),
  rated('Rated'),
  reviews('Reviews'),
  watchlists('Watchlists'),
  favourites('Favourites');

  const ActivityFeedFilter(this.label);
  final String label;

  bool matches(ActivityListItem item) => switch (this) {
        ActivityFeedFilter.all => true,
        ActivityFeedFilter.watched =>
          item.type == ActivityListType.movieWatched ||
              item.type == ActivityListType.showWatched,
        ActivityFeedFilter.rated => item.type == ActivityListType.movieRating ||
            item.type == ActivityListType.showRating,
        ActivityFeedFilter.reviews =>
          item.type == ActivityListType.movieReview ||
              item.type == ActivityListType.showReview,
        ActivityFeedFilter.watchlists =>
          item.type == ActivityListType.movieWatchlist ||
              item.type == ActivityListType.showWatchlist,
        ActivityFeedFilter.favourites =>
          item.type == ActivityListType.favoriteMovie ||
              item.type == ActivityListType.favoriteShow ||
              item.type == ActivityListType.favoritePerson,
      };
}

class ActivityFilterBar extends StatelessWidget {
  const ActivityFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ActivityFeedFilter selected;
  final ValueChanged<ActivityFeedFilter> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ActivityFeedFilter.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final filter = ActivityFeedFilter.values[index];
            final active = selected == filter;
            return ChoiceChip(
              selected: active,
              onSelected: (_) => onChanged(filter),
              showCheckmark: false,
              label: Text(filter.label),
              labelStyle: TextStyle(
                color: active ? Colors.black : FlixieColors.light,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: FlixieColors.primary,
              backgroundColor: FlixieColors.surface,
              side: BorderSide(
                color:
                    active ? FlixieColors.primary : FlixieColors.tabBarBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            );
          },
        ),
      );
}
