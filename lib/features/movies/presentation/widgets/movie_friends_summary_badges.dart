import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';

class MovieFriendsSummaryBadges extends StatelessWidget {
  const MovieFriendsSummaryBadges(
      {super.key, required this.activities, required this.movieId});
  final List<MovieFriendActivity> activities;
  final int? movieId;

  @override
  Widget build(BuildContext context) {
    final ratings = activities
        .map((item) => item.rating)
        .whereType<int>()
        .where((rating) => rating >= 1 && rating <= 10)
        .toList();
    final average = ratings.isEmpty
        ? null
        : (ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(1);
    final recommended =
        activities.where((item) => item.recommended == true).length;
    final watchlisted = activities.where((item) => item.onWatchlist).length;
    final favourites = activities.where((item) => item.favorited).length;
    return Wrap(spacing: 5, runSpacing: 5, children: [
      if (!hideMovieRatings(context, movieId))
        _badge(
            Icons.star_rounded,
            context.colors.warning,
            average == null ? 'No ratings' : '$average/10 avg',
            average == null
                ? 'No friend ratings yet'
                : 'Friends’ average rating: $average out of 10 from ${ratings.length} ratings'),
      _badge(Icons.thumb_up_alt_rounded, context.colors.success, '$recommended',
          '$recommended friends recommend'),
      _badge(Icons.bookmark_rounded, context.colors.warning, '$watchlisted',
          'On $watchlisted friends’ watchlists'),
      _badge(Icons.favorite_rounded, context.colors.danger, '$favourites',
          'Favourited by $favourites friends'),
    ]);
  }

  Widget _badge(IconData icon, Color color, String text, String description) {
    return Tooltip(
        message: description,
        child: Semantics(
          label: description,
          excludeSemantics: true,
          child: FlixiePill.label(
              label: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Flexible(child: Text(text)),
          ])),
        ));
  }
}
