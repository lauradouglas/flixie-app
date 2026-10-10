import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_formatters.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'friend_plan_button.dart';
import 'friend_plan_styles.dart';

enum FriendPlanStage { invitation, schedule, scheduled, afterWatch }

class FriendPlanStageView extends StatelessWidget {
  const FriendPlanStageView(
      {super.key,
      required this.stage,
      required this.request,
      required this.myUserId,
      required this.title,
      required this.onAccept,
      required this.onDecline,
      required this.onSuggestSchedule,
      required this.onRespondToProposal,
      required this.onConfirmWatched,
      required this.onNotThisTime,
      required this.onChangeMovie,
      this.myAvatar,
      this.myProfileBadges = const [],
      this.busy = false});
  final FriendPlanStage stage;
  final WatchRequest request;
  final String myUserId, title;
  final ProfileAvatar? myAvatar;
  final List<String> myProfileBadges;
  final bool busy;
  final VoidCallback onAccept,
      onDecline,
      onSuggestSchedule,
      onConfirmWatched,
      onNotThisTime,
      onChangeMovie;
  final void Function(WatchScheduleProposal, String) onRespondToProposal;
  WatchRequest get r => request;
  WatchRequestUser? get other => r.otherUser(myUserId);
  String get friend => other?.username ?? 'your friend';
  bool get needsMovie =>
      r.candidates.length > 1 && r.selectedCandidateId == null;
  @override
  Widget build(BuildContext context) => switch (stage) {
        FriendPlanStage.invitation => _invite(context),
        FriendPlanStage.schedule => _schedule(context),
        FriendPlanStage.scheduled => _scheduled(context),
        FriendPlanStage.afterWatch => _afterWatch(context),
      };
  Widget _invite(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        if (r.candidates.length > 1)
          Text(
              '${r.candidates.length} starting suggestions. You can both add films after joining.',
              style: friendPlanBody.copyWith(color: context.colors.light))
        else
          Text(
              r.proposedDate != null
                  ? r.proposedDateOnly
                      ? 'Accept to confirm this film and date.'
                      : 'Accept to confirm this film and time.'
                  : 'Join the plan, then choose a date together.',
              style: friendPlanBody.copyWith(color: context.colors.light)),
        if (r.proposedDate != null) ...[
          const SizedBox(height: 12),
          Text(_date(context, r.proposedDate!, dateOnly: r.proposedDateOnly),
              style:
                  friendPlanTitle.copyWith(color: context.colors.textPrimary)),
        ],
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [
            _avatar(true, 64),
            const SizedBox(height: 8),
            Text('You',
                style: friendPlanBody.copyWith(color: context.colors.light))
          ]),
          Column(children: [
            _avatar(false, 64),
            const SizedBox(height: 8),
            Text(friend,
                style: friendPlanBody.copyWith(color: context.colors.light))
          ]),
        ]),
        const SizedBox(height: 24),
        Text(
            r.message?.trim().isNotEmpty == true
                ? r.message!
                : 'Fancy a movie night?',
            style: friendPlanTitle.copyWith(color: context.colors.textPrimary)),
        if (r.requesterId != myUserId) ...[
          _button('I’m in', Icons.check, onAccept),
          if (!needsMovie && r.proposedDate != null)
            _button('Suggest another time', Icons.schedule, onSuggestSchedule,
                primary: false),
          _button('Not this time', Icons.close, onDecline, primary: false),
        ] else
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Waiting for $friend to join.',
                  style: friendPlanBody.copyWith(color: context.colors.light))),
      ]);

  Widget _schedule(BuildContext context) {
    final proposal = r.latestPendingProposal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      if (proposal == null) ...[
        Text(
            'Movie confirmed. Choose a date that works for you both. A time is optional.',
            style: friendPlanBody.copyWith(color: context.colors.light)),
        _button('Suggest a date', Icons.calendar_month, onSuggestSchedule),
        _button('Change movie', Icons.movie_outlined, onChangeMovie,
            primary: false),
      ] else ...[
        Text(
            proposal.proposerId == myUserId
                ? 'Your proposal'
                : '$friend’s proposal',
            style: friendPlanTitle.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: 12),
        Text(
            proposal.proposedFor == null
                ? 'Time to agree'
                : _date(context, proposal.proposedFor!,
                    dateOnly: proposal.dateOnly),
            style: friendPlanBody.copyWith(color: context.colors.light)),
        if (proposal.location?.isNotEmpty == true)
          Text(proposal.location!,
              style: friendPlanBody.copyWith(color: context.colors.light)),
        const SizedBox(height: 16),
        _person(
            context,
            true,
            proposal.proposerId == myUserId ? 'Works for me' : 'Pending',
            proposal.proposerId == myUserId),
        _person(
            context,
            false,
            proposal.proposerId != myUserId ? 'Works for me' : 'Pending',
            proposal.proposerId != myUserId),
        if (proposal.proposerId != myUserId)
          _button('Works for me', Icons.check,
              () => onRespondToProposal(proposal, 'accepted'))
        else
          Text('Waiting for $friend to confirm.',
              style: friendPlanBody.copyWith(color: context.colors.light)),
        _button('Suggest another time', Icons.schedule, onSuggestSchedule,
            primary: false),
        const SizedBox(height: 10),
        Text('A new proposal needs agreement again.',
            style: friendPlanBody.copyWith(color: context.colors.light)),
      ],
    ]);
  }

  Widget _scheduled(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        _badge('Both confirmed', context.colors.success),
        const SizedBox(height: 16),
        _person(context, true, 'Confirmed', true),
        _person(context, false, 'Confirmed', true),
        if (!r.watchConfirmations.any((c) => c.userId == myUserId)) ...[
          _button('Log watch', Icons.check_rounded, onConfirmWatched),
          const SizedBox(height: 8),
          Text('Watched early? You can log it now.',
              style: friendPlanBody.copyWith(color: context.colors.medium)),
        ],
        _button('Add to calendar', Icons.calendar_month, () async {
          final saved = await WatchCalendarService.addScheduledWatch(
              title: title,
              scheduledFor: r.scheduledFor!,
              dateOnly: r.scheduledDateOnly,
              location: r.location,
              runtimeMinutes: r.movie?.runtimeMinutes);
          if (!saved && context.mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
                type: FlixieToastType.error,
                content: const Text('Could not open your calendar.')));
          }
        }, primary: false),
        _button('Reschedule', Icons.schedule, onSuggestSchedule,
            primary: false),
      ]);

  Widget _afterWatch(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        Text('How did $title go?',
            style: friendPlanTitle.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: 8),
        Text('Log your watch when you’re ready. You each respond separately.',
            style: friendPlanBody.copyWith(color: context.colors.light)),
        if (!r.watchConfirmations.any((c) => c.userId == myUserId)) ...[
          _button('Log your watch', Icons.check, onConfirmWatched),
          _button('I didn’t make it', Icons.event_busy, onNotThisTime,
              primary: false),
        ],
        const SizedBox(height: 20),
        Text('Your progress',
            style: friendPlanTitle.copyWith(color: context.colors.textPrimary)),
        for (final mine in [true, false])
          Builder(builder: (_) {
            final entry = r.watchConfirmations
                .where((c) => c.userId == (mine ? myUserId : other?.id))
                .firstOrNull;
            return _person(
                context,
                mine,
                entry == null
                    ? 'To respond'
                    : entry.watched
                        ? 'Logged'
                        : 'Didn’t make it',
                entry != null);
          }),
        const SizedBox(height: 8),
        Text('Missed it? Your friend can still log their watch.',
            style: friendPlanBody.copyWith(color: context.colors.light)),
      ]);

  Widget _avatar(bool mine, double size) => ProfileAvatarView(
        avatar: mine ? myAvatar : other?.avatar,
        profileBadges:
            mine ? myProfileBadges : other?.profileBadges ?? const [],
        fallbackText:
            mine ? 'Y' : (friend.isEmpty ? '?' : friend[0].toUpperCase()),
        fallbackColor: FlixieColors.primary,
        size: size,
      );

  Widget _person(BuildContext context, bool mine, String status, bool done) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          _avatar(mine, 36),
          const SizedBox(width: 10),
          Expanded(
              child: Text(mine ? 'You' : friend,
                  style: friendPlanBody.copyWith(color: context.colors.light))),
          Expanded(
              child: Text(status,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: done
                          ? context.colors.success
                          : context.colors.medium))),
          const SizedBox(width: 8),
          Icon(done ? Icons.check_circle : Icons.schedule,
              size: 20,
              color: done ? context.colors.success : context.colors.medium),
        ]),
      );
  String _date(BuildContext context, DateTime value, {bool dateOnly = false}) =>
      dateOnly
          ? formatWatchPlanDateTime(value, dateOnly: true)
          : '${MaterialLocalizations.of(context).formatMediumDate(value.toLocal())}, ${TimeOfDay.fromDateTime(value.toLocal()).format(context)}';
  Widget _button(String label, IconData icon, VoidCallback? action,
          {bool primary = true}) =>
      FriendPlanButton(
          label: label,
          icon: icon,
          action: action,
          primary: primary,
          busy: busy);
  Widget _badge(String label, Color color) =>
      FlixiePill.label(label: Text(label));
}
