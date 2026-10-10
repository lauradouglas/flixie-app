import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/profile/presentation/widgets/movie_taste_badge.dart';

import 'profile_viewing_insights.dart';

class ProfileStatsContent extends StatelessWidget {
  const ProfileStatsContent({
    super.key,
    required this.wrapped,
    required this.failed,
    required this.onRetry,
    required this.ratings,
    required this.reviewCount,
    required this.favoriteGenres,
    required this.directorPeople,
    required this.onWrapped,
    required this.onFindMovies,
    required this.onSeeRatings,
  });

  final bool failed;
  final VoidCallback onRetry;
  final MovieWrapped? wrapped;
  final List<MovieRating> ratings;
  final int reviewCount;
  final List<dynamic> favoriteGenres;
  final Map<int, Person> directorPeople;
  final VoidCallback onWrapped;
  final VoidCallback onFindMovies;
  final VoidCallback onSeeRatings;

  @override
  Widget build(BuildContext context) {
    final data = wrapped;
    if (data == null) {
      return failed
          ? TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Couldn’t load stats. Retry'))
          : const ContentPlaceholder(label: 'Loading statistics');
    }
    final average = ratings.isEmpty
        ? '–'
        : (ratings.fold<int>(0, (sum, item) => sum + item.rating) /
                ratings.length)
            .toStringAsFixed(1);
    final maxGenre = data.topGenres.isEmpty
        ? 1
        : data.topGenres
            .map((item) => item.count)
            .reduce((a, b) => a > b ? a : b);

    final sortedRatings = [...ratings]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final now = DateTime.now();
    final monthCount = data.year == now.year ? now.month : 12;
    final counts = List<int>.filled(monthCount, 0);
    for (final month in data.monthlyWatchCounts) {
      if (month.month > 0 && month.month <= monthCount) {
        counts[month.month - 1] = month.count;
      }
    }
    final maxMonth = counts.fold<int>(1, (a, b) => a > b ? a : b);
    final minutes = (data.totalHoursWatched * 60).round();
    const months = [
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
    ];
    Widget heading(String title) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 12),
          child: Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.white)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (failed)
        TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Couldn’t refresh stats. Retry')),
      Text('Movie watching · ${data.year}',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.colors.white)),
      const SizedBox(height: 14),
      Wrap(spacing: 28, runSpacing: 12, children: [
        _StatsValue('${data.rewatchCount}', 'Watches'),
        _StatsValue('${data.totalMoviesWatched}', 'Unique movies'),
        _StatsValue('${minutes ~/ 60}h ${minutes % 60}m', 'Estimated time'),
      ]),
      Align(
          alignment: Alignment.centerRight,
          child: TextButton(
              onPressed: onWrapped,
              child: Text('View ${data.year} Wrapped ›'))),
      heading('Monthly watches'),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < counts.length; i++)
              Semantics(
                  label: '${months[i]} ${data.year}: ${counts[i]} watches',
                  child: ExcludeSemantics(
                      child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      Text('${counts[i]}',
                          style: TextStyle(
                              color: context.colors.light, fontSize: 12)),
                      const SizedBox(height: 4),
                      SizedBox(
                          height: 70,
                          width: 28,
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: counts[i] == 0
                                    ? 2
                                    : counts[i] / maxMonth * 70,
                                decoration: BoxDecoration(
                                    color: counts[i] == 0
                                        ? context.colors.surfaceElevated
                                        : context.colors.primaryText,
                                    borderRadius: BorderRadius.circular(4)),
                              ))),
                      const SizedBox(height: 6),
                      Text(months[i],
                          style: TextStyle(
                              color: context.colors.light, fontSize: 12)),
                    ]),
                  ))),
          ])),
      if (data.year == now.year)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${months[now.month - 1]} in progress',
                style: TextStyle(color: context.colors.medium, fontSize: 12))),
      if (data.insights != null)
        ProfileViewingInsights(
            insights: data.insights!,
            year: data.year,
            movies: data.totalMoviesWatched),
      heading('Your ratings · All time'),
      Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onSeeRatings,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          '$average / 10 average · ${ratings.length} movie ratings',
                          style: TextStyle(color: context.colors.light))),
                  Icon(Icons.chevron_right, color: context.colors.primaryText),
                ])),
          )),
      Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('$reviewCount movie and show reviews · All time',
              style: TextStyle(color: context.colors.medium))),
      if (data.topMovies.isNotEmpty && data.topMovies.first.watchCount > 1) ...[
        heading('Most watched again'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () =>
              context.push(movieDetailPath(data.topMovies.first.movieId)),
          title: Text(data.topMovies.first.title),
          subtitle: Text(
              '${data.topMovies.first.watchCount} watches in ${data.year}'),
          leading: data.topMovies.first.posterPath == null
              ? const Icon(Icons.movie_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w185${data.topMovies.first.posterPath}',
                      width: 40,
                      height: 60,
                      fit: BoxFit.cover)),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
      if (data.topGenres.isNotEmpty) ...[
        heading('Top genres · ${data.year}'),
        ...data.topGenres.take(4).map((genre) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(genre.name)),
                Text('${genre.count}')
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                  value: maxGenre <= 0 ? 0 : genre.count / maxGenre,
                  minHeight: 5,
                  color: context.colors.primaryText,
                  backgroundColor: context.colors.surfaceElevated),
            ]))),
        Text('Viewing counts by genre; movies can have several genres.',
            style: TextStyle(color: context.colors.medium, fontSize: 12)),
      ],
      if (favoriteGenres.isNotEmpty) ...[
        heading('Your taste'),
        MovieTasteBadge(favoriteGenres: favoriteGenres, compact: true),
      ],
      if (data.topDirectors.isNotEmpty) ...[
        heading('Top directors · ${data.year}'),
        ...data.topDirectors.take(4).map((director) {
          final profile = directorPeople[director.personId]?.profileImgUrl;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
                backgroundImage: profile == null
                    ? null
                    : CachedNetworkImageProvider(
                        'https://image.tmdb.org/t/p/w185$profile'),
                child:
                    profile == null ? const Icon(Icons.person_outline) : null),
            title: Text(director.name),
            subtitle: Text('${director.count} films'),
            trailing: director.personId == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: director.personId == null
                ? null
                : () => context.push(personDetailPath(director.personId!)),
          );
        }),
      ],
      if (ratings.isNotEmpty) ...[
        const SizedBox(height: 18),
        ProfileStatsHeader(title: 'Recent ratings', onSeeAll: onSeeRatings),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final rating in sortedRatings.take(8))
                Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _RecentRatingTile(rating: rating)),
            ])),
      ],
    ]);
  }
}

class _StatsValue extends StatelessWidget {
  const _StatsValue(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: context.colors.white)),
        Text(label,
            style: TextStyle(color: context.colors.medium, fontSize: 13)),
      ]);
}

class _RecentRatingTile extends StatelessWidget {
  const _RecentRatingTile({required this.rating});
  final MovieRating rating;
  @override
  Widget build(BuildContext context) {
    final path = rating.movie?.posterPath;
    return GestureDetector(
      onTap: () => context.push(movieDetailPath(rating.movieId)),
      child: SizedBox(
          width: 88,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                    width: 88,
                    height: 132,
                    child: path == null
                        ? ColoredBox(
                            color: context.colors.surfaceElevated,
                            child: const Icon(Icons.movie_outlined))
                        : CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w342$path',
                            fit: BoxFit.cover))),
            const SizedBox(height: 5),
            Text(rating.movie?.title ?? 'Movie',
                style: TextStyle(color: context.colors.light, fontSize: 12)),
            Row(children: [
              Icon(Icons.star_rounded, color: context.colors.warning, size: 15),
              const SizedBox(width: 3),
              Text('${rating.rating}/10',
                  style: TextStyle(
                      color: context.colors.light,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700))
            ]),
          ])),
    );
  }
}

class ProfileStatsHeader extends StatelessWidget {
  const ProfileStatsHeader({
    super.key,
    required this.title,
    required this.onSeeAll,
    this.count,
    this.actionLabel = 'See all',
  });

  final String actionLabel;
  final String title;
  final int? count;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: 12,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title,
                    style: TextStyle(
                        color: context.colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                if (count != null) ...[
                  FlixiePill.label(label: Text('$count')),
                ],
              ],
            ),
            TextButton(onPressed: onSeeAll, child: Text(actionLabel)),
          ],
        ),
      );
}
