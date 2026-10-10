import 'friend_plan_stage_view.dart';
import 'friend_plan_button.dart';
import 'friend_plan_styles.dart';
import 'friend_plan_choices.dart';
import 'friend_plan_recap.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
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
      this.headerTopInset = 0,
      this.myProfileBadges = const [],
      this.busy = false});
  final WatchRequest request;
  final String myUserId;
  final double headerTopInset;
  final ProfileAvatar? myAvatar;
  final List<String> myProfileBadges;
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

  Widget _movieLink(Widget child, String key) {
    final candidate =
        chosen ?? (r.candidates.length == 1 ? r.candidates.first : null);
    final movieId = candidate?.movieId ?? r.movieId ?? r.movie?.id;
    final showId = candidate?.showId ?? r.showId;
    final route = movieId != null
        ? '/movies/$movieId'
        : showId != null
            ? '/shows/$showId'
            : null;
    if (route == null) return child;
    return Semantics(
      button: true,
      label: 'View $title details',
      child: InkWell(
        key: ValueKey(key),
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }

  bool get complete =>
      r.isCompleted ||
      [r.requesterId, r.recipientId]
          .every((id) => r.watchConfirmations.any((c) => c.userId == id));
  bool get due =>
      r.watchConfirmations.isNotEmpty ||
      (r.normalizedScheduleStatus == 'AGREED' &&
          r.scheduledFor != null &&
          watchPlanScheduleHasPassed(r.scheduledFor!,
              dateOnly: r.scheduledDateOnly));
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
    if (r.latestPendingProposal != null) {
      return r.latestPendingProposal!.dateOnly
          ? 'Agree on a date'
          : 'Agree on a time';
    }
    if (due) return 'After the watch';
    if (r.scheduledFor != null && r.normalizedScheduleStatus == 'AGREED') {
      return 'Scheduled';
    }
    return 'Agree on a date';
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
      if (r.hasSelectedTitle) _movieHeader(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!r.hasSelectedTitle) ...[
              _summary(),
              const SizedBox(height: 20),
              Divider(color: context.colors.tabBarBorder),
              const SizedBox(height: 16),
            ],
            if (complete)
              _recap()
            else if (r.isDeclined || r.isCancelled || r.isExpired) ...[
              const SizedBox(height: 16),
              Text(
                  'This plan is closed. You can make another whenever you’re ready.',
                  style: friendPlanBody.copyWith(color: context.colors.light)),
              _button('Plan another movie', Icons.add, widget.onNewPlan),
              _button('Close', Icons.close, widget.onClosePlan, primary: false),
            ] else if (r.isPending)
              _stage(FriendPlanStage.invitation)
            else if (needsMovie)
              _movies()
            else if (r.latestPendingProposal != null)
              _stage(FriendPlanStage.schedule)
            else if (due)
              _stage(FriendPlanStage.afterWatch)
            else if (r.scheduledFor != null &&
                r.normalizedScheduleStatus == 'AGREED')
              _stage(FriendPlanStage.scheduled)
            else
              _stage(FriendPlanStage.schedule),
            if (!complete) _message(),
            if (!complete &&
                !r.isPending &&
                !r.isDeclined &&
                !r.isCancelled &&
                !r.isExpired)
              TextButton(
                  onPressed: widget.busy ? null : widget.onCancelPlan,
                  child: const Text('Cancel plan')),
          ])),
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
                    style: friendPlanTitle.copyWith(
                        color: context.colors.textPrimary)),
                const SizedBox(height: 5),
                Text('With $friend',
                    style:
                        friendPlanBody.copyWith(color: context.colors.light)),
                const SizedBox(height: 8),
                Text(stage == 'Scheduled' ? widget.scheduledLabel : stage,
                    style:
                        friendPlanBody.copyWith(color: context.colors.light)),
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
        : (stage == 'Agree on a time' || stage == 'Agree on a date')
            ? const Color(0xFF00D4D4)
            : context.colors.primaryText;
    final icon = complete
        ? Icons.star_outline
        : stage == 'Scheduled'
            ? Icons.check_circle_outline
            : (stage == 'Agree on a time' || stage == 'Agree on a date')
                ? Icons.schedule
                : r.isPending
                    ? Icons.mail_outline
                    : due
                        ? Icons.movie_outlined
                        : Icons.local_movies_outlined;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _movieLink(_summaryPosters(88), 'watch-plan-summary-poster'),
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
        _movieLink(
            Text(title,
                style: friendPlanTitle
                    .copyWith(color: context.colors.textPrimary)
                    .copyWith(fontSize: 25, fontWeight: FontWeight.w900)),
            'watch-plan-summary-title'),
        const SizedBox(height: 2),
        Text('Watch plan',
            style: friendPlanBody
                .copyWith(color: context.colors.light)
                .copyWith(
                    color: context.colors.primaryText,
                    fontWeight: FontWeight.w700)),
        if (r.scheduledFor != null && !needsMovie) ...[
          const SizedBox(height: 8),
          Text(widget.scheduledLabel,
              style: friendPlanBody.copyWith(color: context.colors.light)),
        ],
        if (r.location?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(r.location!,
              style: friendPlanBody.copyWith(color: context.colors.light)),
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

  Widget _stage(FriendPlanStage stage) => FriendPlanStageView(
      stage: stage,
      request: r,
      myUserId: widget.myUserId,
      title: title,
      myAvatar: widget.myAvatar,
      myProfileBadges: widget.myProfileBadges,
      busy: widget.busy,
      onAccept: widget.onAccept,
      onDecline: widget.onDecline,
      onSuggestSchedule: widget.onSuggestSchedule,
      onRespondToProposal: widget.onRespondToProposal,
      onConfirmWatched: widget.onConfirmWatched,
      onNotThisTime: widget.onNotThisTime,
      onChangeMovie: widget.onChangeMovie);

  Widget _movies() => FriendPlanChoices(
      request: r,
      myUserId: widget.myUserId,
      showFinalChoices: _showFinalChoices,
      candidateChoiceDraft: widget.candidateChoiceDraft,
      busy: widget.busy,
      onReviewChanged: (value) => setState(() => _reviewMovies = value),
      onSaveCandidateChoices: widget.onSaveCandidateChoices,
      onAddCandidate: widget.onAddCandidate,
      onRemoveCandidate: widget.onRemoveCandidate,
      onSelectCandidate: widget.onSelectCandidate,
      onToggleCandidateChoice: widget.onToggleCandidateChoice);

  String? get backdrop => chosen?.backdropPath ?? r.movie?.backdropPath;
  Widget _movieHeader() =>
      Stack(key: const ValueKey('watch-plan-backdrop-header'), children: [
        if (backdrop?.isNotEmpty == true)
          Positioned.fill(
              child: Image.network(
            backdrop!.startsWith('http')
                ? backdrop!
                : 'https://image.tmdb.org/t/p/w1280$backdrop',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )),
        Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [
                0,
                .25,
                .75,
                1
              ],
              colors: [
                context.colors.background.withValues(alpha: .85),
                context.colors.background.withValues(alpha: .35),
                context.colors.background.withValues(alpha: .8),
                context.colors.background
              ]),
        ))),
        Padding(
            padding:
                EdgeInsets.fromLTRB(24, widget.headerTopInset + 40, 24, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _movieLink(
                    WatchPlanPoster(path: poster, title: title, width: 80),
                    'watch-plan-movie-poster'),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (!complete) ...[
                        Text(stage.toUpperCase(),
                            style: TextStyle(
                                color: context.colors.primaryText,
                                fontWeight: FontWeight.w900,
                                fontSize: 12)),
                        const SizedBox(height: 8),
                      ],
                      _movieLink(
                          Text(title,
                              style: TextStyle(
                                  color: context.colors.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800)),
                          'watch-plan-movie-title'),
                      const SizedBox(height: 8),
                      if (r.scheduledFor != null)
                        Text('Planned ${widget.scheduledLabel}',
                            style: TextStyle(
                                color: context.colors.light, height: 1.4)),
                      if (r.location?.isNotEmpty == true)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(r.location!,
                                style: TextStyle(color: context.colors.light))),
                      const SizedBox(height: 14),
                      Wrap(
                          spacing: 8,
                          children: [_avatar(true, 38), _avatar(false, 38)]),
                    ])),
              ],
            )),
      ]);

  Widget _recap() => FriendPlanRecap(
      title: title,
      request: r,
      myUserId: widget.myUserId,
      myAvatar: widget.myAvatar,
      myProfileBadges: widget.myProfileBadges,
      busy: widget.busy,
      onConfirmWatched: widget.onConfirmWatched,
      onNewPlan: widget.onNewPlan);

  Widget _avatar(bool mine, double size) => ProfileAvatarView(
        avatar: mine ? widget.myAvatar : other?.avatar,
        profileBadges:
            mine ? widget.myProfileBadges : other?.profileBadges ?? const [],
        fallbackText:
            mine ? 'Y' : (friend.isEmpty ? '?' : friend[0].toUpperCase()),
        fallbackColor: FlixieColors.primary,
        size: size,
      );

  Widget _message() => _button('Message $friend', Icons.chat_bubble_outline,
      other?.id == null ? null : () => context.push('/chat/${other!.id}'),
      primary: false);
  Widget _button(String label, IconData icon, VoidCallback? action,
          {bool primary = true}) =>
      FriendPlanButton(
          label: label,
          icon: icon,
          action: action,
          primary: primary,
          busy: widget.busy);
  Widget _badge(String label, Color color) {
    return FlixiePill.label(label: Text(label));
  }
}
