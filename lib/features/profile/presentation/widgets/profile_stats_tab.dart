import 'recent_milestones.dart';
import 'package:flixie_app/models/profile_milestone.dart';
import 'package:flixie_app/features/profile/presentation/widgets/monthly_watch_summary.dart';
import 'package:flixie_app/features/profile/presentation/pages/milestones_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/models/user.dart' as models;

import 'profile_stats_content.dart';

class ProfileStatsTab extends StatelessWidget {
  const ProfileStatsTab(
      {super.key,
      required this.wrapped,
      this.milestones,
      this.milestonesLoading = false,
      this.milestonesFailed = false,
      this.onRetryMilestones,
      required this.failed,
      required this.onRetry,
      required this.ratings,
      required this.reviewCount,
      required this.directorPeople,
      required this.user});
  final MovieWrapped? wrapped;
  final ProfileMilestones? milestones;
  final bool milestonesLoading, milestonesFailed;
  final VoidCallback? onRetryMilestones;
  final bool failed;
  final VoidCallback onRetry;
  final List<MovieRating> ratings;
  final int reviewCount;
  final Map<int, Person> directorPeople;
  final models.User? user;
  @override
  Widget build(BuildContext context) {
    final favoriteGenres = user?.favoriteGenres ?? const <dynamic>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CustomScrollView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            if (wrapped?.insights != null)
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileStatsHeader(
                          title: 'This month',
                          onSeeAll: () => context.push('/stats'),
                          actionLabel: 'View stats'),
                      MonthlyWatchSummary(
                        movies: (wrapped!.insights!['monthMovies'] as num?)
                                ?.toInt() ??
                            0,
                        episodes: (wrapped!.insights!['monthEpisodes'] as num?)
                                ?.toInt() ??
                            0,
                        onDiscover: () => context.push('/search'),
                        onLog: () => context.push('/search'),
                      ),
                    ]),
              )),
            if (user?.id != null)
              SliverToBoxAdapter(
                  child: RecentMilestones(
                data: milestones,
                loading: milestonesLoading,
                failed: milestonesFailed,
                onRetry: onRetryMilestones,
              )),
            if (user?.id != null)
              SliverToBoxAdapter(
                  child: Padding(
                padding: EdgeInsets.zero,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('View all milestones'),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  MilestonesScreen(userId: user!.id))),
                    )),
              )),
          ]),
      ProfileStatsContent(
        wrapped: wrapped,
        failed: failed,
        onRetry: onRetry,
        ratings: ratings,
        reviewCount: reviewCount,
        favoriteGenres: favoriteGenres,
        directorPeople: directorPeople,
        onWrapped: () => context.push('/wrapped/${user?.id ?? ''}'),
        onFindMovies: () => context.push('/search'),
        onSeeRatings: () => context.push('/stats'),
      ),
    ]);
  }
}
