import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/request_poster_placeholder.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_plan_activity.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class GroupFocusedWatchPlan extends StatelessWidget {
  const GroupFocusedWatchPlan({
    super.key,
    required this.req,
    required this.isMyRequest,
    required this.canManage,
    required this.isProcessing,
    required this.needsReply,
    required this.posterUrl,
    required this.proposedDate,
    required this.stage,
    required this.responseActions,
    required this.manageActions,
    this.scheduleActions,
    required this.movieChoicesBuilder,
    required this.activity,
    required this.completedContent,
    required this.postWatchContent,
    required this.onChangeMovie,
    required this.onEditSchedule,
  });

  final GroupWatchRequest req;
  final bool isMyRequest;
  final bool canManage;
  final bool isProcessing;
  final bool needsReply;
  final String? posterUrl;
  final String proposedDate;
  final Widget stage;
  final Widget responseActions;
  final Widget manageActions;
  final Widget? scheduleActions;
  final WidgetBuilder movieChoicesBuilder;
  final Widget activity;
  final Widget completedContent;
  final Widget postWatchContent;
  final VoidCallback onChangeMovie;
  final VoidCallback onEditSchedule;

  @override
  Widget build(BuildContext context) {
    Widget surface({required Widget child}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );
    // A response row is only created for invited members. The person who
    // created the plan is therefore always a participant and is implicitly
    // accepted, but must be rendered separately here.
    final invitees = req.memberStatuses
        .where((member) => member.memberId != req.userId)
        .toList(growable: false);
    final accepted = invitees
        .where((member) => member.status == 'ACCEPTED')
        .toList(growable: false);
    final declined = invitees
        .where((member) => member.status == 'DECLINED')
        .toList(growable: false);

    if (req.status == WatchRequestStatus.completed) {
      return completedContent;
    }

    final scheduledAt = DateTime.tryParse(req.scheduledFor ?? '')?.toLocal();
    if (scheduledAt != null && !scheduledAt.isAfter(DateTime.now())) {
      return postWatchContent;
    }
    final showManageActions = canManage && scheduleActions == null;
    final overviewActions = <Widget>[
      if (showManageActions) manageActions,
      if (scheduleActions != null) scheduleActions!,
    ];
    final showChangeMovie = isMyRequest && req.selectedCandidateId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stage,
              const SizedBox(height: 14),
              if (req.selectedCandidateId == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Planning a watch together',
                      style: TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _acceptedParticipantSummary(accepted),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _poster(posterUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.movieTitle ?? 'Watch Plan',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: FlixieColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          _acceptedParticipantSummary(accepted),
                          if (proposedDate.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(proposedDate,
                                style: const TextStyle(
                                    color: FlixieColors.secondary,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: FlixieColors.tabBarBorder),
              const SizedBox(height: 12),
              _planProgress(
                accepted.length + 1,
                invitees.length + 1,
                declined.length,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        surface(
          child: _planOverview(
            timeAction: req.scheduledFor?.isNotEmpty == true && canManage
                ? TextButton.icon(
                    onPressed: isProcessing ? null : onEditSchedule,
                    icon: const Icon(Icons.edit_calendar_outlined, size: 15),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                : null,
            movieAction: showChangeMovie
                ? TextButton.icon(
                    onPressed: isProcessing ? null : onChangeMovie,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Change', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                : null,
            actions: overviewActions.isEmpty
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0;
                          index < overviewActions.length;
                          index++) ...[
                        if (index > 0) const SizedBox(height: 12),
                        overviewActions[index],
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (needsReply) surface(child: responseActions),
        if (needsReply) const SizedBox(height: 12),
        if (req.status == WatchRequestStatus.completed) ...[
          surface(
            child: GroupCompletedWatchSummary(req: req),
          ),
          const SizedBox(height: 12),
        ],
        if (req.selectedCandidateId != null) ...[
          surface(child: _chosenMovie()),
          const SizedBox(height: 12),
        ],
        if (req.candidates.isNotEmpty && req.selectedCandidateId == null) ...[
          surface(child: movieChoicesBuilder(context)),
          const SizedBox(height: 12),
        ],
        surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Participants',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FlixieColors.success,
                        width: 2.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: ProfileAvatarView(
                        avatar: req.requesterAvatar,
                        fallbackText: (req.requesterUsername?.isNotEmpty == true
                                ? req.requesterUsername![0]
                                : '?')
                            .toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 42,
                        profileBadges: req.requesterProfileBadges,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 62,
                    child: Text(
                      isMyRequest ? 'You' : req.requesterUsername ?? 'Creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FlixieColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
                ...invitees.map((member) {
                  final acceptedMember = member.status == 'ACCEPTED';
                  final declinedMember = member.status == 'DECLINED';
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: declinedMember
                              ? FlixieColors.danger
                              : acceptedMember
                                  ? FlixieColors.success
                                  : FlixieColors.tabBarBorder,
                          width: 2.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ProfileAvatarView(
                          avatar: member.avatar,
                          fallbackText:
                              (member.username ?? '?')[0].toUpperCase(),
                          fallbackColor: FlixieColors.primary,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 62,
                      child: Text(member.username ?? 'Member',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: declinedMember
                                  ? FlixieColors.danger
                                  : acceptedMember
                                      ? FlixieColors.success
                                      : FlixieColors.medium,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]);
                }),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: '${accepted.length + 1} accepted',
                    style: const TextStyle(color: FlixieColors.success),
                  ),
                  TextSpan(
                    text:
                        ' · ${invitees.length - accepted.length - declined.length} waiting',
                    style: const TextStyle(color: FlixieColors.warning),
                  ),
                  if (declined.isNotEmpty)
                    TextSpan(
                      text: ' · ${declined.length} declined',
                      style: const TextStyle(color: FlixieColors.danger),
                    ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        surface(
          child: activity,
        ),
      ],
    );
  }

  Widget _poster(String? posterUrl, {bool compact = false}) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: compact ? 64 : 105,
          height: compact ? 96 : 158,
          child: posterUrl == null
              ? const RequestPosterPlaceholder()
              : CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover),
        ),
      );

  Widget _acceptedParticipantSummary(
    List<GroupRequestMemberStatus> accepted,
  ) {
    final participants =
        <({ProfileAvatar? avatar, String fallback, List<String> badges})>[
      (
        avatar: req.requesterAvatar,
        fallback: req.requesterUsername?.trim().isNotEmpty == true
            ? req.requesterUsername!.trim()[0].toUpperCase()
            : '?',
        badges: req.requesterProfileBadges,
      ),
      ...accepted.map(
        (member) => (
          avatar: member.avatar,
          fallback: member.username?.trim().isNotEmpty == true
              ? member.username!.trim()[0].toUpperCase()
              : '?',
          badges: member.profileBadges,
        ),
      ),
    ];
    const avatarSize = 34.0;
    const overlap = 10.0;
    return Semantics(
      label: 'With ${participants.length} accepted participants',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('With',
            style: TextStyle(color: FlixieColors.light, fontSize: 14)),
        const SizedBox(width: 8),
        SizedBox(
          width:
              avatarSize + (participants.length - 1) * (avatarSize - overlap),
          height: avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < participants.length; index++)
                Positioned(
                  left: index * (avatarSize - overlap),
                  child: _compactParticipantAvatar(
                    avatar: participants[index].avatar,
                    fallback: participants[index].fallback,
                    badges: participants[index].badges,
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _compactParticipantAvatar({
    required ProfileAvatar? avatar,
    required String fallback,
    required List<String> badges,
  }) {
    const specialBadges = {
      'FOUNDER',
      'OG_USER',
      'VERIFIED',
      'EARLY_ADOPTER',
      'FOUNDING_FILM_FRIEND',
    };
    final hasSpecialFrame = badges.any(specialBadges.contains);
    if (hasSpecialFrame) {
      return ProfileAvatarView(
        avatar: avatar,
        fallbackText: fallback,
        fallbackColor: FlixieColors.primary,
        size: badges.contains('FOUNDER') ? 26 : 28,
        profileBadges: badges,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.65),
        ),
      ),
      child: ProfileAvatarView(
        avatar: avatar,
        fallbackText: fallback,
        fallbackColor: FlixieColors.primary,
        size: 32,
      ),
    );
  }

  Widget _planOverview({
    Widget? timeAction,
    Widget? movieAction,
    Widget? actions,
  }) {
    final scheduled = req.scheduledFor?.trim();
    final proposed = req.proposedDate?.trim();
    final time = scheduled?.isNotEmpty == true
        ? 'Scheduled · $proposedDate'
        : proposed?.isNotEmpty == true
            ? 'Proposed · $proposedDate'
            : 'Time undecided';
    final count = req.candidates.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Plan overview',
          style: TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      _overviewRow(Icons.calendar_month_outlined, time, trailing: timeAction),
      const SizedBox(height: 9),
      _overviewRow(
          Icons.location_on_outlined,
          req.location?.trim().isNotEmpty == true
              ? req.location!.trim()
              : 'Decide where to watch'),
      const SizedBox(height: 9),
      _overviewRow(
        Icons.movie_filter_outlined,
        '$count movie option${count == 1 ? '' : 's'}',
        trailing: movieAction,
      ),
      if (actions != null) ...[
        const SizedBox(height: 12),
        const Divider(height: 1, color: FlixieColors.tabBarBorder),
        const SizedBox(height: 12),
        actions,
      ],
    ]);
  }

  Widget _overviewRow(IconData icon, String text, {Widget? trailing}) =>
      Row(children: [
        Icon(icon, size: 18, color: FlixieColors.secondary),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ]);

  Widget _chosenMovie() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Chosen movie',
            style: TextStyle(
                color: FlixieColors.light,
                fontSize: 17,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(children: [
          _poster(posterUrl, compact: true),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(req.movieTitle ?? 'Watch Plan',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Selected for this Watch Plan',
                    style: TextStyle(
                        color: FlixieColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ])),
          const Icon(Icons.check_circle_rounded,
              color: FlixieColors.success, size: 25),
        ]),
      ]);

  Widget _planProgress(int accepted, int total, int declined) {
    final steps = [
      ('Invited', true),
      ('Group replied', accepted + declined >= total),
      ('Movie chosen', req.selectedCandidateId != null),
      ('Scheduled', req.scheduledFor != null),
      ('Watched', req.status == WatchRequestStatus.completed),
    ];
    // A plan can carry later data (for example, a suggested movie) before
    // everyone has accepted. The visual track must still represent one
    // continuous journey rather than disconnected completed segments.
    final completedSegments = <bool>[];
    var previousStepComplete = true;
    for (final step in steps) {
      final complete = previousStepComplete && step.$2;
      completedSegments.add(complete);
      previousStepComplete = complete;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Plan progress',
          style: TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Row(children: [
        for (var index = 0; index < steps.length; index++) ...[
          Expanded(
              child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                      color: completedSegments[index]
                          ? FlixieColors.success
                          : FlixieColors.tabBarBorder,
                      borderRadius: BorderRadius.circular(4)))),
          if (index < steps.length - 1) const SizedBox(width: 5),
        ],
      ]),
      const SizedBox(height: 9),
      Text(
          steps
                  .where((step) => !step.$2)
                  .map((step) => 'Next: ${step.$1}')
                  .firstOrNull ??
              'Plan complete',
          style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    ]);
  }
}
