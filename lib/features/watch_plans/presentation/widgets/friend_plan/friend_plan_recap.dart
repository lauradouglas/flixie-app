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
      this.onNotThisTime,
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
  final VoidCallback? onNotThisTime;
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
    final allResponded = r.viewingPersonIds.every(r.hasCurrentUserConfirmed);
    final missed = r.watchConfirmations.where((c) => !c.watched).length;
    final allViewersRated =
        allResponded && watched.isNotEmpty && ratings.length == watched.length;
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
              child: Text(
                  r.isSharedViewing
                      ? 'Shared viewing'
                      : allResponded
                          ? 'Your recap'
                          : 'Recap so far',
                  style: friendPlanTitle.copyWith(
                      color: context.colors.textPrimary)))
        ]),
        if (!allResponded) ...[
          const SizedBox(height: 12),
          Text(
              'Waiting for everyone to log. This recap will update as they do.',
              style: friendPlanBody.copyWith(color: context.colors.light)),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final people = metric(
              Icons.people_outline,
              context.colors.primaryText,
              '${watched.length} watched',
              r.isSharedViewing
                  ? (allResponded && missed > 0
                      ? '$missed ${missed == 1 ? 'wasn’t' : 'weren’t'} there'
                      : 'Of ${r.viewingPersonIds.length} people')
                  : watched.length == 2
                      ? 'You and $friend'
                      : 'Of 2 people');
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
                      ? (r.isSharedViewing && allResponded
                          ? 'No ratings for this viewing'
                          : 'No one has rated yet')
                      : r.isSharedViewing && allViewersRated
                          ? (missed > 0
                              ? 'Everyone who watched has rated'
                              : 'Everyone has rated')
                          : r.isSharedViewing && allResponded
                              ? '${ratings.length} of ${watched.length} viewers rated'
                              : ratings.length == 1
                                  ? (r.isSharedViewing
                                      ? '1 of ${r.viewingPersonIds.length} rated'
                                      : 'Only 1 of 2 rated')
                                  : (r.isSharedViewing
                                      ? '${ratings.length} of ${r.viewingPersonIds.length} rated'
                                      : 'Both rated'));
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
        if (r.isSharedViewing && allResponded)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Everyone has responded',
                  style:
                      friendPlanBody.copyWith(color: context.colors.success))),
        if (recommendations > 0)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                  '$recommendations ${recommendations == 1 ? 'recommends' : 'recommend'} it',
                  style:
                      friendPlanBody.copyWith(color: context.colors.success))),
      ])),
      if (r.isSharedViewing &&
          !r.isTerminal &&
          !r.watchConfirmations.any((c) => c.userId == myUserId)) ...[
        _button('Log your watch', Icons.check, onConfirmWatched),
        if (onNotThisTime != null)
          _button('I wasn’t there', Icons.event_busy, onNotThisTime,
              primary: false),
      ],
      for (final person in r.isSharedViewing
          ? r.viewingPeople
          : <WatchRequestUser?>[null, other]) ...[
        const SizedBox(height: 8),
        WatchPlanSurface(
            padding: const EdgeInsets.all(12),
            child: _recapPerson(context,
                r.isSharedViewing ? person?.id == myUserId : person == null,
                person: person)),
      ],
      if (mine != null) ...[
        const SizedBox(height: 24),
        WatchPlanSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your diary note',
              style:
                  friendPlanTitle.copyWith(color: context.colors.textPrimary)),
          const SizedBox(height: 8),
          Text(
              mine.watchComment?.trim().isNotEmpty == true
                  ? mine.watchComment!
                  : 'Share your thoughts on $title.',
              style: friendPlanBody.copyWith(color: context.colors.light)),
          _button(
              mine.watchComment?.trim().isNotEmpty == true
                  ? 'Edit your thoughts'
                  : 'Add your thoughts',
              Icons.edit_outlined,
              onConfirmWatched,
              primary: false),
        ])),
      ],
      const SizedBox(height: 12),
      _button('Plan another movie', Icons.add, onNewPlan),
      if (!r.isSharedViewing) _message(context),
    ]);
  }

  Widget _recapPerson(BuildContext context, bool mine,
      {WatchRequestUser? person}) {
    final subject = person ?? other;
    final entry = r.watchConfirmations
        .where((c) => c.userId == (mine ? myUserId : subject?.id))
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
        ProfileAvatarView(
            avatar: mine ? myAvatar ?? person?.avatar : subject?.avatar,
            profileBadges: mine
                ? (person?.profileBadges ?? myProfileBadges)
                : subject?.profileBadges ?? const [],
            fallbackText:
                mine ? 'Y' : (subject?.displayName ?? '?').characters.first,
            fallbackColor: FlixieColors.primary,
            size: 44),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mine ? 'You' : subject?.displayName ?? friend,
              style: friendPlanTitle.copyWith(
                  color: context.colors.textPrimary, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
              entry == null
                  ? 'To respond'
                  : entry.watched
                      ? 'Watched'
                      : (r.isSharedViewing ? 'Wasn’t there' : 'Didn’t make it'),
              style: friendPlanBody.copyWith(color: context.colors.light)),
          if (compact) rating,
          if (!mine &&
              entry?.watched == true &&
              entry?.watchComment?.isNotEmpty == true)
            Text(entry!.watchComment!,
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
