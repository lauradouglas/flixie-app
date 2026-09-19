import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/watch_request.dart';

/// Direct plans use the group flow's visual language, with two-person agreement.
class FriendWatchPlanFlow extends StatefulWidget {
  const FriendWatchPlanFlow(
      {super.key,
      required this.request,
      required this.myUserId,
      required this.compact,
      required this.scheduledLabel,
      required this.onOpen,
      required this.onAccept,
      required this.onDecline,
      required this.onSuggestSchedule,
      required this.onRespondToProposal,
      required this.onConfirmWatched,
      required this.onNotThisTime,
      required this.onClosePlan,
      required this.onNewPlan,
      required this.onCancelPlan,
      required this.candidateChoiceDraft,
      required this.onToggleCandidateChoice,
      required this.onSaveCandidateChoices,
      required this.onAddCandidate,
      required this.onRemoveCandidate,
      required this.onSelectCandidate,
      required this.onChangeMovie,
      this.myAvatar,
      this.busy = false});
  final WatchRequest request;
  final String myUserId;
  final ProfileAvatar? myAvatar;
  final bool compact, busy;
  final String scheduledLabel;
  final VoidCallback onOpen,
      onAccept,
      onDecline,
      onSuggestSchedule,
      onConfirmWatched,
      onNotThisTime,
      onClosePlan,
      onNewPlan,
      onCancelPlan,
      onAddCandidate,
      onChangeMovie;
  final void Function(WatchScheduleProposal, String) onRespondToProposal;
  final Set<String> candidateChoiceDraft;
  final ValueChanged<String> onToggleCandidateChoice,
      onRemoveCandidate,
      onSelectCandidate;
  final Future<bool> Function() onSaveCandidateChoices;
  @override
  State<FriendWatchPlanFlow> createState() => _FriendWatchPlanFlowState();
}

class _FriendWatchPlanFlowState extends State<FriendWatchPlanFlow> {
  bool _reviewMovies = false;
  bool get _isCreator => r.requesterId == widget.myUserId;
  bool get _showFinalChoices =>
      _isCreator || _reviewMovies || r.proposedCandidateId != null;
  WatchRequest get r => widget.request;
  WatchRequestUser? get other => r.otherUser(widget.myUserId);
  String get friend => other?.username ?? 'your friend';
  WatchPlanCandidate? get chosen => r.candidates
      .where((c) => c.id == (r.selectedCandidateId ?? r.proposedCandidateId))
      .firstOrNull;
  String get title =>
      chosen?.title ??
      r.movie?.title ??
      (r.candidates.length == 1 ? r.candidates.first.title : null) ??
      'Movie night';
  String? get poster =>
      chosen?.posterPath ??
      r.movie?.posterPath ??
      r.candidates.firstOrNull?.posterPath;
  bool get complete =>
      r.isCompleted ||
      [r.requesterId, r.recipientId]
          .every((id) => r.watchConfirmations.any((c) => c.userId == id));
  bool get due =>
      r.watchConfirmations.isNotEmpty ||
      (r.normalizedScheduleStatus == 'AGREED' &&
          r.scheduledFor != null &&
          !r.scheduledFor!.isAfter(DateTime.now()));
  bool get needsMovie =>
      r.candidates.length > 1 && r.selectedCandidateId == null;
  String get stage {
    if (complete) return 'Your recap';
    if (r.isDeclined || r.isCancelled || r.isExpired) return 'Plan closed';
    if (r.isPending) {
      return r.requesterId == widget.myUserId
          ? 'Waiting for $friend'
          : 'Join the plan';
    }
    if (needsMovie) {
      return _showFinalChoices
          ? (_isCreator ? 'Finalise movie' : 'Waiting for creator')
          : 'Pick movies';
    }
    if (r.latestPendingProposal != null) return 'Agree on a time';
    if (due) return 'After the watch';
    if (r.scheduledFor != null && r.normalizedScheduleStatus == 'AGREED') {
      return 'Scheduled';
    }
    return 'Agree on a time';
  }

  @override
  void didUpdateWidget(covariant FriendWatchPlanFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != r.id ||
        (oldWidget.request.proposedCandidateId != null &&
            r.proposedCandidateId == null)) {
      _reviewMovies = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _card();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _summary(),
      const SizedBox(height: 20),
      Divider(color: context.colors.tabBarBorder),
      const SizedBox(height: 16),
      if (complete)
        _recap()
      else if (r.isDeclined || r.isCancelled || r.isExpired) ...[
        const SizedBox(height: 16),
        Text('This plan is closed. You can make another whenever you’re ready.',
            style: _body.copyWith(color: context.colors.light)),
        _button('Plan another movie', Icons.add, widget.onNewPlan),
        _button('Close', Icons.close, widget.onClosePlan, primary: false),
      ] else if (r.isPending)
        _invite()
      else if (needsMovie)
        _movies()
      else if (r.latestPendingProposal != null)
        _schedule()
      else if (due)
        _afterWatch()
      else if (r.scheduledFor != null && r.normalizedScheduleStatus == 'AGREED')
        _scheduled()
      else
        _schedule(),
      if (!complete) _message(),
      if (!complete &&
          !r.isPending &&
          !r.isDeclined &&
          !r.isCancelled &&
          !r.isExpired)
        TextButton(
            onPressed: widget.busy ? null : widget.onCancelPlan,
            child: const Text('Cancel plan')),
    ]);
  }

  Widget _card() => InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(18),
        child: WatchPlanSurface(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _summaryPosters(76),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: _title.copyWith(color: context.colors.textPrimary)),
                const SizedBox(height: 5),
                Text('With $friend',
                    style: _body.copyWith(color: context.colors.light)),
                const SizedBox(height: 8),
                Text(stage == 'Scheduled' ? widget.scheduledLabel : stage,
                    style: _body.copyWith(color: context.colors.light)),
                const SizedBox(height: 10),
                _badge(
                    complete ? 'Watched' : stage,
                    complete || stage == 'Scheduled'
                        ? context.colors.success
                        : context.colors.primaryText),
                const SizedBox(height: 10),
                Row(children: [
                  _avatar(true, 28),
                  const SizedBox(width: 6),
                  _avatar(false, 28)
                ]),
              ])),
          Icon(Icons.chevron_right, color: context.colors.medium),
        ])),
      );

  Widget _summaryPosters(double width) {
    final suggestions = r.candidates.take(3).toList();
    if (chosen != null || suggestions.length < 2) {
      return WatchPlanPoster(path: poster, title: title, width: width);
    }
    const offset = 10.0;
    return SizedBox(
      width: width + offset * (suggestions.length - 1),
      height: width * 1.5 + offset * (suggestions.length - 1),
      child: Stack(
        children: [
          for (var i = suggestions.length - 1; i >= 0; i--)
            Positioned(
              left: offset * i,
              top: offset * i,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
                child: WatchPlanPoster(
                  path: suggestions[i].posterPath,
                  title: suggestions[i].title,
                  width: width,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summary() {
    final colour = complete || stage == 'Scheduled'
        ? context.colors.success
        : stage == 'Agree on a time'
            ? const Color(0xFF00D4D4)
            : context.colors.primaryText;
    final icon = complete
        ? Icons.star_outline
        : stage == 'Scheduled'
            ? Icons.check_circle_outline
            : stage == 'Agree on a time'
                ? Icons.schedule
                : r.isPending
                    ? Icons.mail_outline
                    : due
                        ? Icons.movie_outlined
                        : Icons.local_movies_outlined;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _summaryPosters(88),
      const SizedBox(width: 14),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: colour, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(stage.toUpperCase(),
                  style: TextStyle(
                      color: colour,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7))),
        ]),
        const SizedBox(height: 8),
        Text(title,
            style: _title
                .copyWith(color: context.colors.textPrimary)
                .copyWith(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text('Watch plan',
            style: _body.copyWith(color: context.colors.light).copyWith(
                color: context.colors.primaryText,
                fontWeight: FontWeight.w700)),
        if (r.scheduledFor != null && !needsMovie) ...[
          const SizedBox(height: 8),
          Text(widget.scheduledLabel,
              style: _body.copyWith(color: context.colors.light)),
        ],
        if (r.location?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(r.location!, style: _body.copyWith(color: context.colors.light)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Tooltip(message: 'You', child: _avatar(true, 38)),
          const SizedBox(width: 8),
          Tooltip(message: friend, child: _avatar(false, 38)),
        ]),
      ])),
    ]);
  }

  Widget _invite() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        if (r.candidates.length > 1)
          Text(
              '${r.candidates.length} starting suggestions. You can both add films after joining.',
              style: _body.copyWith(color: context.colors.light))
        else
          Text(
              r.proposedDate != null
                  ? 'Accept to confirm this film and time.'
                  : 'Join the plan, then find a time together.',
              style: _body.copyWith(color: context.colors.light)),
        if (r.proposedDate != null) ...[
          const SizedBox(height: 12),
          Text(_date(r.proposedDate!),
              style: _title.copyWith(color: context.colors.textPrimary)),
        ],
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Column(children: [
            _avatar(true, 64),
            const SizedBox(height: 8),
            Text('You', style: _body.copyWith(color: context.colors.light))
          ]),
          Column(children: [
            _avatar(false, 64),
            const SizedBox(height: 8),
            Text(friend, style: _body.copyWith(color: context.colors.light))
          ]),
        ]),
        const SizedBox(height: 24),
        Text(
            r.message?.trim().isNotEmpty == true
                ? r.message!
                : 'Fancy a movie night?',
            style: _title.copyWith(color: context.colors.textPrimary)),
        if (r.requesterId != widget.myUserId) ...[
          _button('I’m in', Icons.check, widget.onAccept),
          if (!needsMovie && r.proposedDate != null)
            _button('Suggest another time', Icons.schedule,
                widget.onSuggestSchedule,
                primary: false),
          _button('Not this time', Icons.close, widget.onDecline,
              primary: false),
        ] else
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Waiting for $friend to join.',
                  style: _body.copyWith(color: context.colors.light))),
      ]);

  Widget _movies() {
    if (_showFinalChoices && !_isCreator) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your picks are saved. $friend will finalise the movie.',
            style: _body.copyWith(color: context.colors.light)),
        _button('Edit my picks', Icons.edit_outlined,
            () => setState(() => _reviewMovies = false),
            primary: false),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!_showFinalChoices) ...[
        Text('What could you watch?',
            style: _title
                .copyWith(color: context.colors.textPrimary)
                .copyWith(fontSize: 22)),
        const SizedBox(height: 6),
      ],
      Text(
          _showFinalChoices
              ? 'Choose the final movie for your plan.'
              : 'Select every title you would happily watch.',
          style: _body.copyWith(color: context.colors.light)),
      const SizedBox(height: 16),
      for (final candidate in r.candidates)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _choiceRow(candidate),
        ),
      if ((_isCreator || !_showFinalChoices) &&
          r.candidates.where((c) => c.addedByUserId == widget.myUserId).length <
              3)
        Center(
            child: TextButton.icon(
          onPressed: widget.busy ? null : widget.onAddCandidate,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add another option'),
          style:
              TextButton.styleFrom(foregroundColor: context.colors.primaryText),
        )),
      if (!_showFinalChoices)
        _button('Save my picks', Icons.playlist_add_check, () async {
          final saved = await widget.onSaveCandidateChoices();
          if (mounted && saved) setState(() => _reviewMovies = true);
        })
      else if (!_isCreator)
        _button('Edit my picks', Icons.edit_outlined,
            () => setState(() => _reviewMovies = false),
            primary: false),
    ]);
  }

  Widget _choiceRow(WatchPlanCandidate candidate) {
    final selected = widget.candidateChoiceDraft.contains(candidate.id);
    final approvals = [r.requesterId, r.recipientId]
        .where(
            (id) => id == widget.myUserId ? selected : candidate.selectedBy(id))
        .length;
    final both = approvals == 2;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: both
            ? context.colors.success.withValues(alpha: .08)
            : context.colors.background.withValues(alpha: .35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: both
                  ? context.colors.success
                  : selected
                      ? FlixieColors.primary
                      : context.colors.tabBarBorder,
              width: both || selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.busy
              ? null
              : () => _showFinalChoices
                  ? widget.onSelectCandidate(candidate.id)
                  : widget.onToggleCandidateChoice(candidate.id),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              WatchPlanPoster(
                  path: candidate.posterPath,
                  title: candidate.title,
                  width: 48),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(candidate.title ?? 'Movie option',
                        style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        both
                            ? 'Both would watch'
                            : '$approvals of 2 would watch',
                        style: TextStyle(
                            color: both
                                ? context.colors.success
                                : context.colors.medium,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ])),
              if (_showFinalChoices) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: FilledButton(
                    onPressed: widget.busy
                        ? null
                        : () => widget.onSelectCandidate(candidate.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Choose', textAlign: TextAlign.center),
                  ),
                ),
              ],
              if (!_showFinalChoices)
                Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? context.colors.success
                        : context.colors.medium),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _schedule() {
    final proposal = r.latestPendingProposal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      if (proposal == null) ...[
        Text('Movie confirmed. Find a time that works for you both.',
            style: _body.copyWith(color: context.colors.light)),
        _button(
            'Suggest a time', Icons.calendar_month, widget.onSuggestSchedule),
        _button('Change movie', Icons.movie_outlined, widget.onChangeMovie,
            primary: false),
      ] else ...[
        Text(
            proposal.proposerId == widget.myUserId
                ? 'Your proposal'
                : '$friend’s proposal',
            style: _title.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: 12),
        Text(
            proposal.proposedFor == null
                ? 'Time to agree'
                : _date(proposal.proposedFor!),
            style: _body.copyWith(color: context.colors.light)),
        if (proposal.location?.isNotEmpty == true)
          Text(proposal.location!,
              style: _body.copyWith(color: context.colors.light)),
        const SizedBox(height: 16),
        _person(
            true,
            proposal.proposerId == widget.myUserId ? 'Works for me' : 'Pending',
            proposal.proposerId == widget.myUserId),
        _person(
            false,
            proposal.proposerId != widget.myUserId ? 'Works for me' : 'Pending',
            proposal.proposerId != widget.myUserId),
        if (proposal.proposerId != widget.myUserId)
          _button('Works for me', Icons.check,
              () => widget.onRespondToProposal(proposal, 'accepted'))
        else
          Text('Waiting for $friend to confirm.',
              style: _body.copyWith(color: context.colors.light)),
        _button(
            'Suggest another time', Icons.schedule, widget.onSuggestSchedule,
            primary: false),
        const SizedBox(height: 10),
        Text('A new proposal needs agreement again.',
            style: _body.copyWith(color: context.colors.light)),
      ],
    ]);
  }

  Widget _scheduled() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        _badge('Both confirmed', context.colors.success),
        const SizedBox(height: 16),
        _person(true, 'Confirmed', true),
        _person(false, 'Confirmed', true),
        _button('Add to calendar', Icons.calendar_month, () async {
          final saved = await WatchCalendarService.addScheduledWatch(
              title: title,
              scheduledFor: r.scheduledFor!,
              location: r.location,
              runtimeMinutes: r.movie?.runtimeMinutes);
          if (!saved && mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
                type: FlixieToastType.error,
                content: const Text('Could not open your calendar.')));
          }
        }),
        _button('Reschedule', Icons.schedule, widget.onSuggestSchedule,
            primary: false),
      ]);

  Widget _afterWatch() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        Text('How did $title go?',
            style: _title.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: 8),
        Text('Log your watch when you’re ready. You each respond separately.',
            style: _body.copyWith(color: context.colors.light)),
        if (!r.watchConfirmations.any((c) => c.userId == widget.myUserId)) ...[
          _button('Log your watch', Icons.check, widget.onConfirmWatched),
          _button('I didn’t make it', Icons.event_busy, widget.onNotThisTime,
              primary: false),
        ],
        const SizedBox(height: 20),
        Text('Your progress',
            style: _title.copyWith(color: context.colors.textPrimary)),
        for (final mine in [true, false])
          Builder(builder: (_) {
            final entry = r.watchConfirmations
                .where((c) => c.userId == (mine ? widget.myUserId : other?.id))
                .firstOrNull;
            return _person(
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
            style: _body.copyWith(color: context.colors.light)),
      ]);

  Widget _recap() {
    final watched = r.watchConfirmations.where((c) => c.watched).toList();
    final ratings = watched.map((c) => c.rating).whereType<int>().toList();
    final recommendations = watched.where((c) => c.recommended == true).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 22),
      if (ratings.isNotEmpty)
        Text(
            '${(ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(1)} / 10',
            style: TextStyle(
                color: context.colors.warning,
                fontSize: 32,
                fontWeight: FontWeight.w800)),
      Text(
          ratings.length == 2
              ? 'Your average'
              : ratings.isEmpty
                  ? 'No ratings yet'
                  : '1 rating',
          style: _body.copyWith(color: context.colors.light)),
      if (ratings.length == 2) ...[
        const SizedBox(height: 12),
        _badge(
            (ratings[0] - ratings[1]).abs() <= 2
                ? 'Similar takes'
                : 'Different takes',
            context.colors.success),
      ],
      const SizedBox(height: 20),
      for (final mine in [true, false])
        Builder(builder: (_) {
          final entry = r.watchConfirmations
              .where((c) => c.userId == (mine ? widget.myUserId : other?.id))
              .firstOrNull;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _person(
                    mine,
                    entry == null
                        ? 'To respond'
                        : !entry.watched
                            ? 'Didn’t make it'
                            : entry.rating == null
                                ? 'No rating'
                                : '${entry.rating} / 10',
                    entry != null),
                if (entry?.watched == true &&
                    entry?.reviewText?.isNotEmpty == true)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(entry!.reviewText!,
                          style: _body.copyWith(color: context.colors.light))),
              ]);
        }),
      if (recommendations > 0)
        Text(recommendations == 2 ? 'Both recommend it' : '1 recommends it',
            style: _body.copyWith(color: context.colors.light)),
      _message(),
      _button('Plan another movie', Icons.add, widget.onNewPlan,
          primary: false),
    ]);
  }

  Widget _avatar(bool mine, double size) {
    final isCreator = (mine ? widget.myUserId : other?.id) == r.requesterId;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCreator ? context.colors.warning : FlixieColors.primary,
          width: 2,
        ),
      ),
      child: ProfileAvatarView(
        avatar: mine ? widget.myAvatar : other?.avatar,
        fallbackText:
            mine ? 'Y' : (friend.isEmpty ? '?' : friend[0].toUpperCase()),
        fallbackColor: FlixieColors.primary,
        size: size - 10,
      ),
    );
  }

  Widget _person(bool mine, String status, bool done) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          _avatar(mine, 36),
          const SizedBox(width: 10),
          Expanded(
              child: Text(mine ? 'You' : friend,
                  style: _body.copyWith(color: context.colors.light))),
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
  Widget _message() => _button('Message $friend', Icons.chat_bubble_outline,
      other?.id == null ? null : () => context.push('/chat/${other!.id}'),
      primary: false);
  Widget _button(String label, IconData icon, VoidCallback? action,
          {bool primary = true}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: primary
              ? FilledButton.icon(
                  onPressed: widget.busy ? null : action,
                  icon: Icon(icon),
                  label: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)))
              : OutlinedButton.icon(
                  onPressed: widget.busy ? null : action,
                  icon: Icon(icon),
                  label: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16))),
        ),
      );
  Widget _badge(String label, Color color) {
    return FlixiePill.label(label: Text(label));
  }

  String _date(DateTime value) =>
      '${MaterialLocalizations.of(context).formatMediumDate(value.toLocal())}, ${TimeOfDay.fromDateTime(value.toLocal()).format(context)}';
}

const _title = TextStyle(
    color: FlixieColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800);
const _body = TextStyle(color: FlixieColors.light, fontSize: 14, height: 1.4);
