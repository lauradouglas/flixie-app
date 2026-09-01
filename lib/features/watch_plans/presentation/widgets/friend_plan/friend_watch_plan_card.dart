import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_post_watch_section.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_movie_choices_section.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_participants_section.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_plan_activity.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_plan_actions.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';
import 'package:flixie_app/models/watch_request.dart';

const _months = [
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
  'Dec',
];

class FriendWatchPlanCard extends StatelessWidget {
  const FriendWatchPlanCard({
    super.key,
    required this.request,
    required this.compact,
    required this.myUserId,
    required this.formattedDate,
    required this.scheduledLabel,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
    required this.onSuggestSchedule,
    required this.onSuggestDifferentTime,
    required this.onEditLocation,
    required this.onRespondToProposal,
    required this.onConfirmWatched,
    required this.onCancelPlan,
    required this.onClosePlan,
    required this.onChooseAcceptanceSchedule,
    required this.candidateChoiceDraft,
    required this.onToggleCandidateChoice,
    required this.onSaveCandidateChoices,
    required this.onViewMovies,
    required this.onAddCandidate,
    required this.onRemoveCandidate,
    required this.onSelectCandidate,
    required this.onChangeMovie,
    required this.onNotThisTime,
    this.onMovieTap,
    this.busyAction,
    this.acceptanceScheduleDraft,
  });

  final WatchRequest request;
  final bool compact;
  final String myUserId;
  final String formattedDate;
  final String scheduledLabel;
  final VoidCallback? onMovieTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;
  final VoidCallback onSuggestSchedule;
  final VoidCallback onSuggestDifferentTime;
  final VoidCallback onEditLocation;
  final void Function(WatchScheduleProposal proposal, String decision)
      onRespondToProposal;
  final VoidCallback onConfirmWatched;
  final VoidCallback onCancelPlan;
  final VoidCallback onClosePlan;
  final VoidCallback onChooseAcceptanceSchedule;
  final Set<String> candidateChoiceDraft;
  final ValueChanged<String> onToggleCandidateChoice;
  final VoidCallback onSaveCandidateChoices;
  final VoidCallback onViewMovies;
  final VoidCallback onAddCandidate;
  final ValueChanged<String> onRemoveCandidate;
  final ValueChanged<String> onSelectCandidate;
  final VoidCallback onChangeMovie;
  final VoidCallback onNotThisTime;
  final FriendWatchPlanAction? busyAction;
  final FriendAcceptanceScheduleDraft? acceptanceScheduleDraft;

  Color get _statusColor {
    if (request.normalizedWatchedStatus == 'WATCHED') {
      return FlixieColors.primary;
    }
    if (request.normalizedWatchedStatus == 'NOT_WATCHED') {
      return FlixieColors.danger;
    }
    if (request.normalizedScheduleStatus == 'AGREED') {
      return FlixieColors.secondary;
    }
    if (request.normalizedScheduleStatus == 'PROPOSED') {
      return FlixieColors.warning;
    }
    if (request.isAccepted) return FlixieColors.success;
    if (request.isDeclined) return FlixieColors.danger;
    return FlixieColors.warning;
  }

  IconData get _statusIcon {
    if (request.normalizedWatchedStatus == 'WATCHED') {
      return Icons.check_circle;
    }
    if (request.normalizedWatchedStatus == 'NOT_WATCHED') {
      return Icons.cancel_outlined;
    }
    if (request.normalizedScheduleStatus == 'AGREED') {
      return Icons.event_available_outlined;
    }
    if (request.normalizedScheduleStatus == 'PROPOSED') {
      return Icons.schedule_send_outlined;
    }
    if (request.isAccepted) return Icons.check_circle_outline;
    if (request.isDeclined) return Icons.cancel_outlined;
    return Icons.hourglass_top_outlined;
  }

  String get _statusLabel => request.planStageFor(myUserId).label;

  @override
  Widget build(BuildContext context) {
    final other = request.otherUser(myUserId);
    final isSent = request.requesterId == myUserId;
    final movie = request.movie;
    final choosingMovie =
        request.selectedCandidateId == null && request.candidates.length > 1;

    final posterUrl = movie?.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie!.posterPath}'
        : null;

    if (!compact) {
      return _buildFullDetail(context, other, isSent, movie, posterUrl);
    }

    if (_useOverviewPlanCards) {
      return _buildOverviewPlanCard(context, other, movie, posterUrl);
    }

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            if (choosingMovie) const SizedBox(width: 12),
            GestureDetector(
              onTap: onMovieTap,
              child: choosingMovie
                  ? _buildCandidatePosterStack()
                  : ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12)),
                      child: SizedBox(
                        width: 92,
                        height: 138,
                        child: posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const _PosterPlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    const _PosterPlaceholder(),
                              )
                            : const _PosterPlaceholder(),
                      ),
                    ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _smallUserAvatar(other),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                  color: FlixieColors.medium, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: request.groupName?.isNotEmpty == true
                                      ? request.groupName
                                      : other?.username ?? 'Friend',
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                    text: isSent ? ' invited' : ' invited you'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.more_horiz_rounded,
                            color: FlixieColors.medium, size: 20),
                      ],
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: onMovieTap,
                      child: Text(
                        choosingMovie
                            ? '${request.candidates.length} movie options'
                            : movie?.title ?? 'Unknown Movie',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (choosingMovie) ...[
                      const SizedBox(height: 6),
                      Text(
                        request.candidates
                            .map((candidate) => candidate.title ?? 'Untitled')
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12),
                      ),
                    ],
                    if (compact) ...[
                      if (_effectiveWatchTime != null) ...[
                        const SizedBox(height: 6),
                        _CompactWatchDetail(
                          icon: Icons.schedule_outlined,
                          text: _dateLabel(_effectiveWatchTime),
                        ),
                      ],
                      if (_effectiveLocation?.isNotEmpty == true) ...[
                        const SizedBox(height: 5),
                        _CompactWatchDetail(
                          icon: Icons.location_on_outlined,
                          text: _effectiveLocation!,
                        ),
                      ],
                      if (request.message?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 7),
                        Text(request.message!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 12)),
                      ],
                      // This card intentionally grows with its content. A
                      // Spacer would require a bounded height here and can
                      // corrupt the semantics/layout pass after the card is
                      // rebuilt.
                      const SizedBox(height: 8),
                      _buildCompactActions(),
                    ],
                    // Detail-only content
                    if (!compact &&
                        request.message != null &&
                        request.message!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${request.message}"',
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (!compact &&
                        (_effectiveWatchTime != null ||
                            _effectiveLocation?.isNotEmpty == true)) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FlixieColors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: FlixieColors.tabBarBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_effectiveWatchTime != null)
                              _WatchDetailRow(
                                icon: request.scheduledFor != null
                                    ? Icons.event_available_outlined
                                    : Icons.schedule_outlined,
                                label: request.scheduledFor != null ||
                                        request.normalizedScheduleStatus ==
                                            'AGREED'
                                    ? 'Scheduled'
                                    : 'Proposed time',
                                value: _dateLabel(_effectiveWatchTime),
                              ),
                            if (_effectiveWatchTime != null &&
                                _effectiveLocation?.isNotEmpty == true)
                              const SizedBox(height: 8),
                            if (_effectiveLocation?.isNotEmpty == true)
                              _WatchDetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: _effectiveLocation!,
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (!compact) const SizedBox(height: 12),
                    // Accept/Decline buttons for pending requests (if recipient)
                    if (!compact)
                      _LifecycleSummary(
                        request: request,
                        scheduledLabel: _scheduleSummaryLabel(),
                        myUserId: myUserId,
                      ),
                    if (!compact && _proposalNoteText != null) ...[
                      const SizedBox(height: 7),
                      _ProposalNote(text: _proposalNoteText!),
                    ],
                    if (!compact) ...[
                      const SizedBox(height: 10),
                      _planActions(),
                      const SizedBox(height: 8),
                    ],
                    // Status badge + date
                    if (!compact)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _statusColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon,
                                    size: 12, color: _statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  _statusLabel,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (formattedDate.isNotEmpty)
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keeps the prior compact card as a low-risk fallback while the refreshed
  // overview is rolled out.
  bool get _useOverviewPlanCards => true;

  Widget _buildOverviewPlanCard(
    BuildContext context,
    WatchRequestUser? other,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) {
    final time = _effectiveWatchTime;
    final isPast = time != null && !time.isAfter(DateTime.now());
    final incoming = request.isPending && request.requesterId != myUserId;
    final hasLogged = request.hasCurrentUserLoggedWatch == true ||
        request.watchConfirmations.any((entry) => entry.userId == myUserId);
    final label = isPast
        ? 'DID YOU WATCH IT?'
        : incoming
            ? 'NEEDS REPLY · ${request.candidates.length} MOVIE OPTIONS'
            : request.normalizedScheduleStatus == 'AGREED'
                ? 'SCHEDULED'
                : 'PLANNING TOGETHER';
    final actionLabel = isPast && !hasLogged
        ? 'Log watch'
        : incoming
            ? 'Choose movies'
            : 'View plan';
    final action = isPast && !hasLogged ? onConfirmWatched : onOpen;
    final title = movie?.title ??
        request.candidates
            .where((candidate) => candidate.id == request.selectedCandidateId)
            .map((candidate) => candidate.title)
            .firstOrNull ??
        '${request.candidates.length} movie options';
    return Material(
      color: FlixieColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 164),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A 320px phone only leaves about 256px inside this card. Keep
              // the essential plan details together at the top, then place
              // context and the CTA on their own, readable row below.
              final useStackedFooter = constraints.maxWidth < 350;
              final posterWidth = useStackedFooter ? 82.0 : 72.0;
              final posterHeight = posterWidth * 1.5;
              final participantText = isPast &&
                      other != null &&
                      request.watchConfirmations
                          .any((entry) => entry.userId == other.id)
                  ? '${other.username} has logged'
                  : 'With ${other?.username ?? 'your group'}';

              final poster = ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: posterWidth,
                  height: posterHeight,
                  child: posterUrl == null
                      ? const _PosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _PosterPlaceholder(),
                        ),
                ),
              );
              final details = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    style: TextStyle(
                      color: isPast
                          ? FlixieColors.secondary
                          : FlixieColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: FlixieColors.medium,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        time == null ? 'Time to be agreed' : _dateLabel(time),
                        maxLines: 2,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ]),
                ],
              );
              final participant = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _smallUserAvatar(other),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      participantText,
                      maxLines: 2,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
              final actionButton = FilledButton(
                onPressed: action,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(actionLabel),
              );

              if (useStackedFooter) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        poster,
                        const SizedBox(width: 14),
                        Expanded(child: details),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: FlixieColors.tabBarBorder),
                    ),
                    Row(children: [
                      Expanded(child: participant),
                      const SizedBox(width: 12),
                      actionButton,
                    ]),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  poster,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        participant
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: posterHeight,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: actionButton,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCandidatePosterStack() {
    final candidates = request.candidates.take(3).toList(growable: false);
    return SizedBox(
      width: 126,
      height: 190,
      child: ClipRect(
        child: Stack(
          children: [
            for (var index = candidates.length - 1; index >= 0; index--)
              Positioned(
                left: index * 10.0,
                top: 12 + index * 7.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 78,
                    height: 136,
                    child: candidates[index].posterPath == null
                        ? const _PosterPlaceholder()
                        : CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w185${candidates[index].posterPath}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const _PosterPlaceholder(),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullDetail(
    BuildContext context,
    WatchRequestUser? other,
    bool isSent,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) {
    final hasCompleted =
        request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';
    if (hasCompleted && request.watchConfirmations.isNotEmpty) {
      return _postWatchSection(other, movie, posterUrl);
    }
    final postWatchTime = _effectiveWatchTime;
    if (postWatchTime != null &&
        !postWatchTime.isAfter(DateTime.now()) &&
        (request.selectedCandidateId != null ||
            request.movie != null ||
            request.candidates.isNotEmpty)) {
      return _postWatchSection(other, movie, posterUrl);
    }
    final companion = request.groupName?.trim().isNotEmpty == true
        ? request.groupName!
        : other?.username ?? 'your group';
    final pendingSchedule = request.latestPendingProposal;
    final hasPendingSchedule = request.normalizedScheduleStatus == 'PROPOSED' &&
        pendingSchedule != null &&
        pendingSchedule.proposedFor != null;
    final canMessage =
        request.groupId?.isEmpty != false && other?.id.isNotEmpty == true;
    final hasChoices = request.isAccepted &&
        request.candidates
            .any((candidate) => candidate.selectedByUserIds.isNotEmpty);
    final hasSchedule = request.normalizedScheduleStatus == 'AGREED';
    final hasWatched =
        request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';
    Color stageColor(bool complete) =>
        complete ? FlixieColors.success : FlixieColors.tabBarBorder;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_rounded, size: 16, color: FlixieColors.success),
              SizedBox(width: 7),
              Text('PLANNING TOGETHER',
                  style: TextStyle(
                      color: FlixieColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4)),
            ]),
            const SizedBox(height: 10),
            Text(
                request.selectedCandidateId == null
                    ? 'Planning a watch together'
                    : movie?.title ?? 'Watch Plan',
                style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 22,
                    height: 1.08,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Row(children: [
              _smallUserAvatar(other),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('With $companion',
                      style: const TextStyle(
                          color: FlixieColors.light, fontSize: 14))),
            ]),
            const Divider(height: 20, color: FlixieColors.tabBarBorder),
            _PlanOverviewRow(
              icon: Icons.calendar_month_outlined,
              label: _effectiveWatchTime == null
                  ? 'Time undecided'
                  : _dateLabel(_effectiveWatchTime),
              action: 'Edit',
              onTap: onSuggestDifferentTime,
            ),
            const SizedBox(height: 5),
            _PlanOverviewRow(
              icon: Icons.location_on_outlined,
              label: _effectiveLocation ?? 'Decide where to watch',
              action: 'Edit',
              onTap: onEditLocation,
            ),
            const SizedBox(height: 5),
            _PlanOverviewRow(
              icon: Icons.movie_filter_outlined,
              label:
                  '${request.candidates.length} movie option${request.candidates.length == 1 ? '' : 's'}',
              action: 'View',
              onTap: onViewMovies,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // A creation-time date is only actionable once this person has
        // accepted the invitation. Showing it earlier puts two competing
        // decisions on screen and makes it look as though the invite is
        // already confirmed.
        if (hasPendingSchedule && request.isAccepted) ...[
          _PlanSurface(
            child: _ScheduleConfirmationCard(
              proposedFor: pendingSchedule.proposedFor!,
              awaitingOtherPerson: pendingSchedule.proposerId == myUserId,
              onConfirm: () => onRespondToProposal(pendingSchedule, 'accepted'),
              onChange: onSuggestDifferentTime,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (_isIncomingInvitation) ...[
          _PlanSurface(child: _planActions(invitationDecisionOnly: true)),
          const SizedBox(height: 14),
        ],
        if (request.candidates.isNotEmpty) ...[
          _PlanSurface(child: _movieChoicesSection()),
          const SizedBox(height: 14),
        ],
        _PlanSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Plan progress',
                style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            _participantsSection(other),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Divider(color: stageColor(true), thickness: 4)),
              SizedBox(width: 10),
              Expanded(
                  child: Divider(color: stageColor(hasChoices), thickness: 4)),
              SizedBox(width: 10),
              Expanded(
                  child: Divider(color: stageColor(hasSchedule), thickness: 4)),
              SizedBox(width: 10),
              Expanded(
                  child: Divider(color: stageColor(hasWatched), thickness: 4)),
            ]),
            const SizedBox(height: 10),
            const Text('Invited → Choose together → Scheduled → Watched',
                style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 14),
        if (request.selectedCandidateId != null &&
            !request.hasCurrentUserConfirmed(myUserId)) ...[
          _PlanSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Watched it already?',
                  style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text(
                  'Log the watch now, even if you watched before the planned time.',
                  style: TextStyle(color: FlixieColors.light, fontSize: 13)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConfirmWatched,
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Log watch early'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        _PlanSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Next step',
                      style: TextStyle(
                          color: FlixieColors.light,
                          fontSize: 19,
                          fontWeight: FontWeight.w800))),
              Text(request.requesterId == myUserId ? 'PLAN OWNER' : 'WAITING',
                  style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(
                request.requesterId == myUserId
                    ? 'After everyone responds, choose the final movie and add the final time.'
                    : 'Choose the movies you would watch, then wait for the plan owner to make the final pick.',
                style: const TextStyle(
                    color: FlixieColors.medium, fontSize: 14, height: 1.35)),
            if (canMessage) ...[
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: _PrimaryActionButton(
                    label: 'Message $companion',
                    onPressed: () => context.push('/chat/${other!.id}'),
                  )),
            ],
          ]),
        ),
      ]),
    );
  }

  // Kept temporarily while the redesigned plan detail is rolled out; it
  // remains a useful reference for the completed-plan and edge-state copy.
  // ignore: unused_element
  Widget _buildLegacyFullDetail(
    BuildContext context,
    WatchRequestUser? other,
    bool isSent,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) {
    final hasSelectedMovie = request.selectedCandidateId != null;
    final currentUserConfirmation = request.watchConfirmations
        .where((confirmation) => confirmation.userId == myUserId)
        .firstOrNull;
    final hasLoggedWatch = request.hasCurrentUserLoggedWatch == true ||
        currentUserConfirmation?.watched == true;
    final hasRatedWatch = currentUserConfirmation?.watched == true &&
        currentUserConfirmation?.rating != null;
    final isAfterWatchTime = _effectiveWatchTime != null &&
        !_effectiveWatchTime!.isAfter(DateTime.now());
    final canLogThisWatch = request.canCompleteFor(myUserId) && !hasLoggedWatch;
    final isWatchFinished =
        request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';
    // Older plans can carry the final title on `movie` without populating
    // selectedCandidateId, so support both representations.
    if ((hasSelectedMovie ||
            request.movie != null ||
            request.candidates.isNotEmpty) &&
        isAfterWatchTime) {
      return _postWatchSection(other, movie, posterUrl);
    }
    // Show the recap as soon as this person has logged their watch. The
    // second person's rating can then arrive into the same recap instead of
    // leaving the first person on the old, past-plan detail screen.
    if ((isWatchFinished || hasLoggedWatch) &&
        request.watchConfirmations.isNotEmpty) {
      return _postWatchSection(other, movie, posterUrl);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hasSelectedMovie
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: onMovieTap,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 116,
                                height: 174,
                                child: posterUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: posterUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const _PosterPlaceholder(),
                                      )
                                    : const _PosterPlaceholder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(movie?.title ?? 'Watch plan',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: FlixieColors.primary,
                                        fontSize: 24,
                                        height: 1.05,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _smallUserAvatar(other),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        request.groupName?.trim().isNotEmpty ==
                                                true
                                            ? 'With ${request.groupName}'
                                            : 'With ${other?.username ?? 'a friend'}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: FlixieColors.light,
                                            fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                _DetailStatusBadge(
                                    icon: _statusIcon,
                                    label: _statusLabel,
                                    color: _statusColor),
                                if (formattedDate.isNotEmpty) ...[
                                  const SizedBox(height: 9),
                                  Text('Created $formattedDate',
                                      style: const TextStyle(
                                          color: FlixieColors.medium,
                                          fontSize: 11)),
                                ],
                                if (!isWatchFinished &&
                                    isSent &&
                                    request.selectedCandidateId != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: busyAction ==
                                            FriendWatchPlanAction.selectingMovie
                                        ? null
                                        : onChangeMovie,
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 16),
                                    label: const Text('Change movie'),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Planning a watch together',
                            style: TextStyle(
                              color: FlixieColors.primary,
                              fontSize: 22,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _smallUserAvatar(other),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  request.groupName?.trim().isNotEmpty == true
                                      ? 'With ${request.groupName}'
                                      : 'With ${other?.username ?? 'a friend'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          _DetailStatusBadge(
                            icon: _statusIcon,
                            label: _statusLabel,
                            color: _statusColor,
                          ),
                          if (formattedDate.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            Text(
                              'Created $formattedDate',
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                if (request.groupId?.isEmpty != false &&
                    other?.id.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  const Divider(
                    height: 1,
                    color: FlixieColors.tabBarBorder,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        color: FlixieColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Need to plan something?',
                          style: TextStyle(
                            color: FlixieColors.light,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/chat/${other!.id}'),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text('Message ${other?.username ?? 'them'}'),
                        style: TextButton.styleFrom(
                          foregroundColor: FlixieColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isIncomingInvitation) ...[
            _PlanSurface(child: _planActions(invitationDecisionOnly: true)),
            const SizedBox(height: 12),
          ],
          if (_hasPlanningAction) ...[
            _PlanSurface(child: _planActions(includeWatchConfirmation: false)),
            const SizedBox(height: 12),
          ],
          // Once a title is locked in, leave the candidate history available
          // without making it compete with the actual Watch Plan details.
          if (request.candidates.isNotEmpty) ...[
            _PlanSurface(
              child: request.selectedCandidateId == null
                  ? _movieChoicesSection()
                  : Material(
                      color: Colors.transparent,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          // Keep the collapsed row aligned with the 14px
                          // surface inset instead of adding a tall default
                          // ListTile rhythm inside this compact summary card.
                          minTileHeight: 48,
                          visualDensity: const VisualDensity(vertical: -2),
                          initiallyExpanded: false,
                          leading: const Icon(
                            Icons.movie_filter_outlined,
                            color: FlixieColors.primary,
                          ),
                          title: const Text(
                            'Movie options',
                            style: TextStyle(
                              color: FlixieColors.light,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${request.candidates.length} titles considered',
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 12,
                            ),
                          ),
                          iconColor: FlixieColors.primary,
                          collapsedIconColor: FlixieColors.medium,
                          children: [
                            const SizedBox(height: 4),
                            _movieChoicesSection(),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
          if (_effectiveWatchTime != null) ...[
            _PlanSurface(
              child: Column(
                children: [
                  if (canLogThisWatch) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isAfterWatchTime
                            ? "After you've watched"
                            : 'Watched early?',
                        style: TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onConfirmWatched,
                        icon: Icon(hasRatedWatch
                            ? Icons.check_circle_rounded
                            : hasLoggedWatch
                                ? Icons.star_rounded
                                : Icons.check_circle_outline_rounded),
                        label: Text(
                          isAfterWatchTime ? 'Log watch' : 'Log watch early',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: FlixieColors.success,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: FlixieColors.success,
                          disabledForegroundColor: Colors.black,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _WatchDetailRow(
                    icon: Icons.event_available_outlined,
                    label:
                        request.scheduledFor != null ? 'Scheduled' : 'Proposed',
                    value: _dateLabel(_effectiveWatchTime),
                  ),
                  const SizedBox(height: 12),
                  _WatchDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: _effectiveLocation ?? 'Not set',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryActionButton(
                          label: 'Add to calendar',
                          onPressed: () =>
                              WatchCalendarService.addScheduledWatch(
                            title: movie?.title ?? 'Watch together',
                            scheduledFor: _effectiveWatchTime!,
                            runtimeMinutes: movie?.runtimeMinutes,
                            note: request.message,
                            location: _effectiveLocation,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _SecondaryActionButton(
                          label: 'Edit plan',
                          onPressed: onSuggestDifferentTime,
                        ),
                      ),
                    ],
                  ),
                  if (request.normalizedScheduleStatus == 'AGREED' ||
                      request.isCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onClosePlan,
                        icon:
                            const Icon(Icons.visibility_off_outlined, size: 18),
                        label: const Text('Close watch plan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FlixieColors.light,
                          side: BorderSide(
                            color: FlixieColors.light.withValues(alpha: .45),
                          ),
                          minimumSize: const Size(0, 46),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _PlanSurface(child: _participantsSection(other)),
          const SizedBox(height: 12),
          _PlanSurface(child: _planActivity()),
          if (request.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _PlanSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Message',
                      style:
                          TextStyle(color: FlixieColors.medium, fontSize: 13)),
                  const SizedBox(height: 7),
                  Text(request.message!.trim(),
                      style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 14,
                          height: 1.4)),
                ],
              ),
            ),
          ],
          if (_shouldShowAfterWatchSection && !isAfterWatchTime) ...[
            const SizedBox(height: 12),
            _PlanSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("After you've watched",
                      style: TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    hasLoggedWatch
                        ? 'Your watch is logged. Add a rating for this viewing.'
                        : 'Log every watch separately and rate this viewing.',
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: hasRatedWatch
                          ? null
                          : hasLoggedWatch
                              ? onMovieTap
                              : request.canCompleteFor(myUserId)
                                  ? onConfirmWatched
                                  : null,
                      icon: Icon(hasRatedWatch
                          ? Icons.check_circle_rounded
                          : hasLoggedWatch
                              ? Icons.star_outline_rounded
                              : Icons.check_circle_outline_rounded),
                      label: Text(
                        hasRatedWatch
                            ? 'Watch rated'
                            : hasLoggedWatch
                                ? 'Rate this watch'
                                : 'Log watch',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: FlixieColors.success,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: FlixieColors.success,
                        disabledForegroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const Divider(height: 28, color: FlixieColors.tabBarBorder),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onSuggestDifferentTime,
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Reschedule'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: request.canCancelFor(myUserId)
                              ? onCancelPlan
                              : null,
                          icon: const Icon(Icons.block_outlined),
                          label: const Text('Cancel plan'),
                          style: TextButton.styleFrom(
                              foregroundColor: FlixieColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (request.watchConfirmations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PlanSurface(child: _planRatingsSummary()),
          ],
          if (request.groupId?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _IconTextAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Open group chat',
              onPressed: () =>
                  context.push('/groups/${request.groupId}?tab=chat'),
            ),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _planActivity() => FriendPlanActivity(
        request: request,
        watchTime: _effectiveWatchTime,
        scheduledLabel: _effectiveWatchTime == null
            ? 'No time set yet'
            : _dateLabel(_effectiveWatchTime!),
      );

  Widget _planRatingsSummary() => FriendPlanRatingsSummary(request: request);

  Widget _postWatchSection(
    WatchRequestUser? other,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) =>
      FriendPostWatchSection(
        request: request,
        myUserId: myUserId,
        other: other,
        movie: movie,
        posterUrl: posterUrl,
        scheduledLabel: _effectiveWatchTime == null
            ? 'Planned watch'
            : _dateLabel(_effectiveWatchTime!),
        location: _effectiveLocation,
        onConfirmWatched: onConfirmWatched,
        onNotThisTime: onNotThisTime,
        onSuggestDifferentTime: onSuggestDifferentTime,
      );

  Widget _smallUserAvatar(WatchRequestUser? user) {
    final response =
        request.participantFor(user?.id ?? '')?.response.toUpperCase();
    final declined = response == 'DECLINED';
    final borderColor = declined ? FlixieColors.danger : Colors.transparent;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ProfileAvatarView(
          avatar: user?.avatar,
          fallbackText: user?.username.isNotEmpty == true
              ? user!.username[0].toUpperCase()
              : '?',
          fallbackColor: FlixieColors.primary,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildCompactActions() {
    if (busyAction != null) {
      return const SizedBox(
        height: 34,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final incoming = request.isPending &&
        request.requesterId != myUserId &&
        (request.recipientId == myUserId ||
            request.participantFor(myUserId) != null);
    if (incoming) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          // Open the plan rather than silently accepting it: this gives the
          // recipient context and takes them straight to movie choices.
          onPressed: onOpen,
          icon: const Icon(Icons.movie_filter_outlined, size: 18),
          label: const Text('Choose movies'),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: onOpen,
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: Text(request.normalizedScheduleStatus == 'AGREED'
            ? 'View plan'
            : 'View plan'),
        style: OutlinedButton.styleFrom(
          foregroundColor: FlixieColors.primary,
          side: const BorderSide(color: FlixieColors.primary),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _movieChoicesSection() => FriendMovieChoicesSection(
        request: request,
        myUserId: myUserId,
        busyAction: busyAction,
        candidateChoiceDraft: candidateChoiceDraft,
        onToggleCandidateChoice: onToggleCandidateChoice,
        onSaveCandidateChoices: onSaveCandidateChoices,
        onAddCandidate: onAddCandidate,
        onRemoveCandidate: onRemoveCandidate,
        onSelectCandidate: onSelectCandidate,
        onChangeMovie: onChangeMovie,
      );

  Widget _participantsSection(WatchRequestUser? other) =>
      FriendParticipantsSection(request: request, other: other);

  Widget _planActions({
    bool invitationDecisionOnly = false,
    bool includeWatchConfirmation = true,
  }) =>
      FriendPlanActions(
        request: request,
        myUserId: myUserId,
        busyAction: busyAction,
        acceptanceScheduleDraft: acceptanceScheduleDraft,
        dateLabel: _dateLabel,
        onAccept: onAccept,
        onDecline: onDecline,
        onSuggestSchedule: onSuggestSchedule,
        onSuggestDifferentTime: onSuggestDifferentTime,
        onEditLocation: onEditLocation,
        onRespondToProposal: onRespondToProposal,
        onConfirmWatched: onConfirmWatched,
        invitationDecisionOnly: invitationDecisionOnly,
        includeWatchConfirmation: includeWatchConfirmation,
      );

  bool get _isIncomingInvitation =>
      request.isPending &&
      request.requesterId != myUserId &&
      (request.recipientId == myUserId ||
          request.participantFor(myUserId) != null);

  bool get _hasPlanningAction {
    // Scheduling is configured in the Watch Plan composer and displayed in
    // the dedicated schedule surface below. Do not repeat that control here.
    if (_isIncomingInvitation) return false;
    // The schedule surface below owns the calendar, time and location actions.
    // Keeping them out of this generic action area avoids duplicate controls.
    if (request.normalizedScheduleStatus == 'AGREED') return false;
    if ((!request.isAccepted && !request.isScheduled) ||
        !request.isWatchRequest ||
        request.canConfirmWatchedFor(myUserId)) {
      return false;
    }
    return request.normalizedWatchedStatus != 'PARTIAL' &&
        request.normalizedWatchedStatus != 'WATCHED' &&
        request.normalizedWatchedStatus != 'NOT_WATCHED';
  }

  bool get _shouldShowAfterWatchSection =>
      request.normalizedScheduleStatus == 'AGREED' ||
      request.canConfirmWatchedFor(myUserId) ||
      request.normalizedWatchedStatus == 'PARTIAL' ||
      request.normalizedWatchedStatus == 'WATCHED' ||
      request.normalizedWatchedStatus == 'NOT_WATCHED';

  String _dateLabel(DateTime? value) {
    if (value == null) return 'the suggested time';
    final local = value.toLocal();
    if (value.isUtc && value.hour == 12 && value.minute == 0) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return 'Watch on ${weekdays[local.weekday - 1]}';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'pm' : 'am';
    if (date == today) return 'Today at $hour:$minute$suffix';
    if (date == today.add(const Duration(days: 1))) {
      return 'Tomorrow at $hour:$minute$suffix';
    }
    return '${local.day} ${_months[local.month - 1]}, $hour:$minute$suffix';
  }

  DateTime? get _effectiveWatchTime =>
      request.scheduledFor ??
      request.latestPendingProposal?.proposedFor ??
      request.proposedDate;

  String? get _effectiveLocation {
    final value = request.location ?? request.latestPendingProposal?.location;
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _scheduleSummaryLabel() {
    final proposal = request.latestPendingProposal;
    if (request.normalizedScheduleStatus == 'PROPOSED' && proposal != null) {
      return _dateLabel(proposal.proposedFor);
    }
    if (request.normalizedScheduleStatus == 'AGREED') {
      return _dateLabel(request.scheduledFor);
    }
    return scheduledLabel;
  }

  WatchScheduleProposal? _visibleScheduleProposal() {
    final proposals = request.scheduleProposals.where((proposal) {
      if (request.normalizedScheduleStatus == 'PROPOSED') {
        return proposal.isPending;
      }
      if (request.normalizedScheduleStatus == 'AGREED') {
        return proposal.normalizedStatus == 'ACCEPTED';
      }
      return false;
    }).toList()
      ..sort((a, b) => _proposalCreatedAt(b).compareTo(_proposalCreatedAt(a)));
    return proposals.isEmpty ? null : proposals.first;
  }

  DateTime _proposalCreatedAt(WatchScheduleProposal proposal) {
    return DateTime.tryParse(proposal.createdAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String? get _proposalNoteText {
    final message = _visibleScheduleProposal()?.message?.trim();
    if (message == null || message.isEmpty) return null;
    return message;
  }
}

class _ScheduleConfirmationCard extends StatelessWidget {
  const _ScheduleConfirmationCard({
    required this.proposedFor,
    required this.awaitingOtherPerson,
    required this.onConfirm,
    required this.onChange,
  });

  final DateTime proposedFor;
  final bool awaitingOtherPerson;
  final VoidCallback onConfirm;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final isDateOnly =
        proposedFor.isUtc && proposedFor.hour == 12 && proposedFor.minute == 0;
    final local = proposedFor.toLocal();
    final date = MaterialLocalizations.of(context).formatFullDate(local);
    final time = TimeOfDay.fromDateTime(local).format(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          awaitingOtherPerson ? 'Waiting for confirmation' : 'Confirm the plan',
          style: TextStyle(
              color: FlixieColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(
          awaitingOtherPerson
              ? isDateOnly
                  ? 'Your friend needs to confirm this watch day.'
                  : 'Your friend needs to confirm this date and time.'
              : isDateOnly
                  ? 'Your friend suggested this watch day.'
                  : 'Your friend suggested this date and time.',
          style: const TextStyle(color: FlixieColors.light, fontSize: 13)),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.event_available_outlined,
              color: FlixieColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(date,
                    style: const TextStyle(
                        color: FlixieColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(isDateOnly ? 'Time to be decided' : time,
                    style: const TextStyle(
                        color: FlixieColors.light, fontSize: 13)),
              ])),
        ]),
      ),
      const SizedBox(height: 12),
      if (!awaitingOtherPerson)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_rounded, size: 18),
            label:
                Text(isDateOnly ? 'Confirm watch day' : 'Confirm date & time'),
          ),
        ),
      if (!awaitingOtherPerson) const SizedBox(height: 6),
      Center(
        child: TextButton(
          onPressed: onChange,
          child: const Text('Suggest a different time'),
        ),
      ),
    ]);
  }
}

class _PlanOverviewRow extends StatelessWidget {
  const _PlanOverviewRow({
    required this.icon,
    required this.label,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: FlixieColors.secondary, size: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: FlixieColors.light, fontSize: 14)),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: FlixieColors.primary,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(action,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _PlanSurface extends StatelessWidget {
  const _PlanSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: child,
    );
  }
}

class _WatchDetailRow extends StatelessWidget {
  const _WatchDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: FlixieColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12.5,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailStatusBadge extends StatelessWidget {
  const _DetailStatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactWatchDetail extends StatelessWidget {
  const _CompactWatchDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: FlixieColors.secondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LifecycleSummary extends StatelessWidget {
  const _LifecycleSummary({
    required this.request,
    required this.scheduledLabel,
    required this.myUserId,
  });

  final WatchRequest request;
  final String scheduledLabel;
  final String myUserId;

  @override
  Widget build(BuildContext context) {
    final text = _summaryText();
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: FlixieColors.light,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String? _summaryText() {
    if (request.isPending) {
      final pending = request.participants
          .where((p) => p.response.toLowerCase() == 'pending')
          .length;
      if (request.requesterId == myUserId) {
        return pending > 0
            ? 'Waiting for $pending response${pending == 1 ? '' : 's'}'
            : 'Waiting for a response';
      }
      return 'Accept the invitation to start making a plan.';
    }
    if (request.isAccepted || request.isScheduled) {
      if (request.normalizedWatchedStatus == 'WATCHED') {
        return 'Watched together';
      }
      if (request.normalizedWatchedStatus == 'NOT_WATCHED') {
        return 'This watch was not completed by both users';
      }
      if (request.normalizedWatchedStatus == 'PARTIAL') {
        return 'One person confirmed. Waiting on the other.';
      }
      if (request.needsWatchConfirmation == true) {
        return 'Scheduled time passed. Confirmation needed.';
      }
      final proposal = request.latestPendingProposal;
      if (request.normalizedScheduleStatus == 'PROPOSED' && proposal != null) {
        return proposal.proposerId == myUserId
            ? 'Waiting for them to respond'
            : 'Choose this time or suggest another that suits you.';
      }
      if (request.normalizedScheduleStatus == 'AGREED') {
        return scheduledLabel.isEmpty
            ? 'Scheduled'
            : 'Scheduled for $scheduledLabel';
      }
      if (request.normalizedScheduleStatus == 'DECLINED') {
        return 'Suggested time declined';
      }
      if (request.normalizedScheduleStatus == 'CANCELLED') {
        return 'Schedule cancelled';
      }
      if (request.isAwaitingScheduleApproval) {
        return 'Accepted · scheduling in progress';
      }
      return 'You’re both up for it. Add a time or location when you’re ready.';
    }
    if (request.isCompleted) {
      final mine = request.participantFor(myUserId);
      if (mine?.rating != null) {
        return 'Your rating: ${mine!.rating!.toStringAsFixed(1)}/10';
      }
      if (mine?.reviewText?.isNotEmpty == true) return 'Your review is saved';
      return 'Watched together';
    }
    if (request.isCancelled) return 'This watch plan was cancelled';
    if (request.isExpired) return 'This Watch Plan expired';
    if (request.isDeclined) return 'This Watch Plan was declined';
    return null;
  }
}

class _ProposalNote extends StatelessWidget {
  const _ProposalNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 13,
            color: FlixieColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: FlixieColors.primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FlixieColors.light,
        side: BorderSide(color: FlixieColors.medium.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _IconTextAction extends StatelessWidget {
  const _IconTextAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: FlixieColors.medium,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder
// ---------------------------------------------------------------------------

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2D40),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: FlixieColors.medium),
      ),
    );
  }
}
