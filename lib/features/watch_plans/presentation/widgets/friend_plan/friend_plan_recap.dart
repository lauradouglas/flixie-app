import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'friend_plan_button.dart';
import 'friend_plan_styles.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';

class FriendPlanRecap extends StatelessWidget {
  const FriendPlanRecap(
      {super.key,
      required this.request,
      required this.title,
      required this.myUserId,
      required this.onConfirmWatched,
      required this.onNewPlan,
      this.myAvatar,
      this.myProfileBadges = const [],
      this.busy = false});
  final WatchRequest request;
  final String title;
  final String myUserId;
  final ProfileAvatar? myAvatar;
  final List<String> myProfileBadges;
  final bool busy;
  final VoidCallback onConfirmWatched, onNewPlan;
  WatchRequest get r => request;
  WatchRequestUser? get other => r.otherUser(myUserId);
  String get friend => other?.username ?? 'your friend';
  @override
  Widget build(BuildContext context) {
    final watched = r.watchConfirmations.where((c) => c.watched).toList();
    final hidden =
        hideMovieRatings(context, r.movieId, isShow: r.showId != null);
    final ratings = hidden
        ? <int>[]
        : watched.map((c) => c.rating).whereType<int>().toList();
    final mine = watched.where((c) => c.userId == myUserId).firstOrNull;
    final recommendations = watched.where((c) => c.recommended == true).length;
    Widget metric(IconData icon, Color color, String value, String detail) =>
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(value,
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(detail,
                    style:
                        friendPlanBody.copyWith(color: context.colors.light)),
              ])),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WatchPlanSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, color: context.colors.primaryText),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Your recap',
                  style: friendPlanTitle.copyWith(
                      color: context.colors.textPrimary)))
        ]),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final people = metric(
              Icons.people_outline,
              context.colors.primaryText,
              '${watched.length} watched',
              watched.length == 2 ? 'You and $friend' : 'Of 2 people');
          final score = metric(
              Icons.star_rounded,
              context.colors.warning,
              hidden
                  ? 'Scores hidden'
                  : ratings.isEmpty
                      ? 'No ratings yet'
                      : '${(ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(1)} avg · ${ratings.length} ${ratings.length == 1 ? 'rating' : 'ratings'}',
              hidden
                  ? 'Rate to see scores'
                  : ratings.isEmpty
                      ? 'No one has rated yet'
                      : ratings.length == 1
                          ? 'Only 1 of 2 rated'
                          : 'Both rated');
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
                children: [people, const SizedBox(height: 18), score]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: people),
            Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: context.colors.tabBarBorder),
            Expanded(child: score)
          ]);
        }),
        if (recommendations > 0)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                  recommendations == 2
                      ? 'Both recommend it'
                      : '1 recommends it',
                  style:
                      friendPlanBody.copyWith(color: context.colors.success))),
      ])),
      for (final isMine in [true, false]) ...[
        const SizedBox(height: 8),
        WatchPlanSurface(
            padding: const EdgeInsets.all(12),
            child: _recapPerson(context, isMine)),
      ],
      if (mine != null) ...[
        const SizedBox(height: 24),
        WatchPlanSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your review',
              style:
                  friendPlanTitle.copyWith(color: context.colors.textPrimary)),
          const SizedBox(height: 8),
          Text(
              mine.reviewText?.trim().isNotEmpty == true
                  ? mine.reviewText!
                  : 'Share your thoughts on $title.',
              style: friendPlanBody.copyWith(color: context.colors.light)),
          _button(
              mine.reviewText?.trim().isNotEmpty == true
                  ? 'Edit your thoughts'
                  : 'Add your thoughts',
              Icons.edit_outlined,
              onConfirmWatched,
              primary: false),
        ])),
      ],
      const SizedBox(height: 12),
      _button('Plan another movie', Icons.add, onNewPlan),
      _message(context),
    ]);
  }

  Widget _recapPerson(BuildContext context, bool mine) {
    final entry = r.watchConfirmations
        .where((c) => c.userId == (mine ? myUserId : other?.id))
        .firstOrNull;
    final hidden = hideMovieRatings(context, r.movieId,
        isShow: r.showId != null, ownerId: entry?.userId);
    final score = entry?.watched != true
        ? null
        : entry?.rating == null
            ? 'No rating added'
            : hidden
                ? 'Rated'
                : '${entry!.rating}/10';
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final rating = score == null
          ? const SizedBox.shrink()
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                  if (entry?.rating != null)
                    Icon(Icons.star_rounded,
                        size: 22, color: context.colors.warning),
                  Text(score,
                      style: friendPlanBody.copyWith(
                          color: context.colors.textPrimary)),
                ]);
      return Row(children: [
        _avatar(mine, 44),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mine ? 'You' : friend,
              style: friendPlanTitle.copyWith(
                  color: context.colors.textPrimary, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
              entry == null
                  ? 'To respond'
                  : entry.watched
                      ? 'Watched'
                      : 'Didn’t make it',
              style: friendPlanBody.copyWith(color: context.colors.light)),
          if (compact) rating,
          if (!mine &&
              entry?.watched == true &&
              entry?.reviewText?.isNotEmpty == true)
            Text(entry!.reviewText!,
                style: friendPlanBody.copyWith(color: context.colors.light)),
        ])),
        if (!compact)
          Flexible(
              fit: FlexFit.tight,
              child: Align(alignment: Alignment.centerRight, child: rating)),
        if (entry?.watched == true)
          Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(Icons.check_circle,
                  color: context.colors.success, size: 26)),
      ]);
    });
  }

  Widget _avatar(bool mine, double size) => ProfileAvatarView(
        avatar: mine ? myAvatar : other?.avatar,
        profileBadges:
            mine ? myProfileBadges : other?.profileBadges ?? const [],
        fallbackText:
            mine ? 'Y' : (friend.isEmpty ? '?' : friend[0].toUpperCase()),
        fallbackColor: FlixieColors.primary,
        size: size,
      );

  Widget _message(BuildContext context) => _button(
      'Message $friend',
      Icons.chat_bubble_outline,
      other?.id == null ? null : () => context.push('/chat/${other!.id}'),
      primary: false);
  Widget _button(String label, IconData icon, VoidCallback? action,
          {bool primary = true}) =>
      FriendPlanButton(
          label: label,
          icon: icon,
          action: action,
          primary: primary,
          busy: busy);
}
