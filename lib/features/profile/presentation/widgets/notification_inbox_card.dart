import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';

bool notificationNeedsResponse(FlixieNotification n) {
  if (n.closed == true) return false;
  if (n.isWatchPlanNotification) {
    final request = n.linkedWatchRequest;
    if (request != null) {
      return WatchPlanDisplayState.needsAttention(request, n.userId);
    }
    final linked = n.link?['groupRequest'];
    final status =
        linked is Map ? linked['status']?.toString().toUpperCase() : null;
    if (const ['CANCELLED', 'COMPLETED', 'EXPIRED', 'DECLINED']
        .contains(status)) {
      return false;
    }
    // With only an event snapshot, do not infer a new task from an update.
    return n.isPending &&
        (n.watchPlanEvent == null ||
            const [
              'PLAN_INVITED',
              'SCHEDULE_PROPOSED',
              'TITLE_PROPOSED',
              'TITLE_SELECTION_REOPENED'
            ].contains(n.watchPlanEvent));
  }
  return n.isRequest && n.isPending;
}

String? notificationPlanLabel(FlixieNotification n) {
  if (!n.isWatchPlanNotification) return null;
  if (n.type == FlixieNotification.groupRequest ||
      n.data?['scope'] == 'GROUP') {
    return 'Group watch plan · ${n.groupWatchGroupName ?? n.groupInviteGroupName ?? 'Your group'}';
  }
  final request = n.link?['request'];
  if (request is Map) {
    for (final key in ['requester', 'recipient']) {
      final user = request[key];
      if (user is Map &&
          user['id'] != null &&
          user['id'] != n.userId &&
          user['username'] is String &&
          (user['username'] as String).isNotEmpty) {
        return 'Watch plan with ${user['username']}';
      }
    }
  }
  return n.senderName.isNotEmpty && n.senderId != n.userId
      ? 'Watch plan with ${n.senderName}'
      : 'Your watch plan';
}

String notificationHeadline(FlixieNotification n) {
  final name = n.senderName.isEmpty ? 'Someone' : n.senderName;
  if (n.type == FlixieNotification.friendRequest) {
    return switch (n.action) {
      FlixieNotification.actionAccepted => '$name accepted your friend request',
      FlixieNotification.actionDeclined => '$name declined your friend request',
      FlixieNotification.actionSent => 'Friend request sent to $name',
      _ => '$name sent you a friend request',
    };
  }
  final group = n.groupWatchGroupName ??
      n.groupInviteGroupName ??
      n.data?['groupName']?.toString() ??
      'your group';
  if (n.type == FlixieNotification.groupInvite) {
    return switch (n.action) {
      FlixieNotification.actionAccepted => 'You joined $group',
      FlixieNotification.actionDeclined =>
        'You declined the invitation to $group',
      _ => '$name invited you to join $group',
    };
  }
  final headline = switch (n.watchPlanEvent) {
    'PLAN_INVITED' => '$name invited you to a watch plan',
    'PLAN_ACCEPTED' => '$name joined your watch plan',
    'PLAN_DECLINED' => '$name declined the invitation',
    'SCHEDULE_PROPOSED' => '$name proposed a new time',
    'SCHEDULE_ACCEPTED' => '$name accepted the proposed time',
    'SCHEDULE_DECLINED' => '$name declined the proposed time',
    'SCHEDULE_KEPT' => 'Your original time is staying',
    'PLAN_SCHEDULED' => 'Your watch plan is confirmed',
    'PLAN_RESCHEDULED' => 'Your watch plan was rescheduled',
    'LOCATION_UPDATED' => 'Location updated',
    'PLAN_CANCELLED' => 'Watch plan cancelled',
    'PLAN_DUE_SOON' => 'Your watch plan starts soon',
    'PLAN_READY_TO_LOG' => 'Did you watch it?',
    'PARTICIPANT_LOGGED' => '$name logged their watch',
    'ALL_PARTICIPANTS_LOGGED' => 'Everyone has logged their watch',
    'RECAP_UPDATED' => 'Your watch recap was updated',
    'TITLE_PROPOSED' => '$name proposed a title',
    'TITLE_SELECTED' => 'Your title has been chosen',
    'TITLE_SELECTION_REOPENED' => 'Film selection reopened',
    'CANDIDATE_ADDED' => 'A new option was added',
    'CANDIDATE_REMOVED' => 'A watch option was removed',
    'CHOICES_SUBMITTED' || 'CHOICES_SAVED' => '$name chose their favourites',
    'CHOICES_COMPLETE' => 'Everyone has made their choices',
    _ => n.message.isNotEmpty ? n.message : 'New notification',
  };
  final isGroup =
      n.type == FlixieNotification.groupRequest || n.data?['scope'] == 'GROUP';
  return isGroup ? '$headline · $group' : headline;
}

class NotificationInboxCard extends StatelessWidget {
  const NotificationInboxCard(
      {super.key,
      required this.notification,
      required this.date,
      required this.onOptions,
      this.onOpen,
      this.onAccept,
      this.onDecline,
      this.processing = false,
      this.profileBadges});
  final FlixieNotification notification;
  final String date;
  final VoidCallback onOptions;
  final VoidCallback? onOpen, onAccept, onDecline;
  final bool processing;
  final List<String>? profileBadges;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final needs = notificationNeedsResponse(n);
    final planLabel = notificationPlanLabel(n);
    final raw = n.link?['request'] ?? n.link?['groupRequest'];
    final options = raw is Map && raw['selectedCandidateId'] == null
        ? (raw['candidates'] as List? ?? []).whereType<Map>().take(3).toList()
        : <Map>[];
    final title =
        n.watchMediaTitle ?? n.groupWatchMovieTitle ?? n.groupWatchGroupName;
    final path = n.watchMediaPosterPath;
    final schedule =
        needs && n.watchRequestScheduleStatus?.toUpperCase() == 'PROPOSED'
            ? n.watchRequestProposedFor
            : n.watchRequestScheduledFor;
    final local = schedule?.toLocal();
    final subtitle = [
      if (title != null && title.isNotEmpty) title,
      if (local != null)
        '${local.day}/${local.month} · ${TimeOfDay.fromDateTime(local).format(context)}',
      if (n.watchRequestLocation?.isNotEmpty == true) n.watchRequestLocation!
    ].join(' · ');
    final cta =
        needs && options.length > 1 && n.linkedWatchRequest?.isAccepted == true
            ? 'Choose films'
            : switch (n.watchPlanEvent) {
                'PLAN_INVITED' => needs ? 'View invitation' : 'View plan',
                'SCHEDULE_PROPOSED' => needs ? 'Review proposal' : 'View plan',
                'PLAN_READY_TO_LOG' => 'Log watch',
                'ALL_PARTICIPANTS_LOGGED' || 'RECAP_UPDATED' => 'View recap',
                _ => n.type == FlixieNotification.groupInvite
                    ? 'View invitation'
                    : n.isWatchPlanNotification
                        ? 'View plan'
                        : n.type == FlixieNotification.listShared
                            ? 'View list'
                            : 'View profile',
              };
    final avatar = ProfileAvatarView(
        avatar: n.senderAvatar,
        fallbackColor: FlixieColors.primary,
        profileBadges: profileBadges ?? n.senderProfileBadges,
        fallbackText: n.senderInitials ?? '!',
        size: 42);
    final cancelled = n.watchPlanEvent == 'PLAN_CANCELLED';
    final positive = n.action == FlixieNotification.actionAccepted ||
        const ['PLAN_ACCEPTED', 'PLAN_SCHEDULED', 'ALL_PARTICIPANTS_LOGGED']
            .contains(n.watchPlanEvent);
    final accent = cancelled
        ? FlixieColors.danger
        : positive
            ? FlixieColors.success
            : FlixieColors.primaryText;
    if (!needs) {
      final detail = cancelled
          ? 'This plan has been cancelled.'
          : n.type == FlixieNotification.friendRequest && positive
              ? 'You’re now friends on Flixie!'
              : subtitle;
      return Semantics(
          label: n.isRead ? null : 'Unread notification',
          child: InkWell(
            onTap: onOpen,
            onLongPress: onOptions,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: FlixieColors.tabBarBorder))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                    padding: const EdgeInsets.all(4),
                    child: n.isWatchPlanNotification && path != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                                imageUrl:
                                    'https://image.tmdb.org/t/p/w185$path',
                                width: 44,
                                height: 66,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.movie_outlined, color: accent)))
                        : avatar),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _NotificationHeadline(notification: n),
                      if (planLabel != null) ...[
                        const SizedBox(height: 5),
                        Text(planLabel,
                            style: const TextStyle(
                                color: FlixieColors.primaryText, fontSize: 12)),
                      ],
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                  cancelled
                                      ? Icons.block_rounded
                                      : positive
                                          ? Icons.check_circle_rounded
                                          : Icons.notifications_outlined,
                                  size: 15,
                                  color: accent),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(detail,
                                      style: const TextStyle(
                                          color: FlixieColors.light,
                                          fontSize: 12))),
                            ]),
                      ],
                      if (cancelled && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                color: FlixieColors.light, fontSize: 12)),
                      ],
                      if (n.isWatchPlanNotification &&
                          !cancelled &&
                          onOpen != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('$cta →',
                                style: const TextStyle(
                                    color: FlixieColors.primaryText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                    ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(date,
                      style: const TextStyle(
                          color: FlixieColors.light, fontSize: 10)),
                  SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                          onPressed: onOptions,
                          tooltip: 'Notification options',
                          icon: Icon(
                              !n.isRead ? Icons.circle : Icons.more_horiz,
                              size: !n.isRead ? 7 : 18,
                              color: FlixieColors.primaryText))),
                ]),
              ]),
            ),
          ));
    }
    return Semantics(
      label: n.isRead ? null : 'Unread',
      child: Material(
        color:
            needs ? FlixieColors.tabBarBackgroundFocused : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onOpen,
          onLongPress: onOptions,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.all(needs ? 14 : 10),
            decoration: BoxDecoration(
                border: needs
                    ? Border.all(
                        color: FlixieColors.primaryText.withValues(alpha: .2))
                    : const Border(
                        bottom: BorderSide(color: FlixieColors.tabBarBorder)),
                borderRadius: needs ? BorderRadius.circular(14) : null),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.all(4), child: avatar),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _NotificationHeadline(notification: n),
                      if (planLabel != null) ...[
                        const SizedBox(height: 5),
                        Text(planLabel,
                            style: const TextStyle(
                                color: FlixieColors.primaryText, fontSize: 12)),
                      ],
                      const SizedBox(height: 5),
                      Text(date,
                          style: const TextStyle(
                              color: FlixieColors.light, fontSize: 11)),
                    ])),
                if (!n.isRead)
                  Padding(
                      padding: const EdgeInsets.only(top: 7, left: 6),
                      child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: FlixieColors.primaryText,
                              shape: BoxShape.circle))),
                SizedBox(
                    width: 36,
                    height: 44,
                    child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Notification options',
                        onPressed: onOptions,
                        icon: const Icon(Icons.more_horiz,
                            size: 19, color: FlixieColors.light))),
              ]),
              if (subtitle.isNotEmpty || options.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (options.length > 1) ...[
                    WatchPlanPosterStack(posters: [
                      for (final c in options)
                        WatchPlanPoster(
                            path: (c['movie']?['posterPath'] ??
                                c['show']?['posterPath'] ??
                                c['posterPath']) as String?,
                            title: (c['movie']?['title'] ??
                                c['show']?['name'] ??
                                c['title']) as String?,
                            width: 42)
                    ]),
                    const SizedBox(width: 12),
                  ] else if (path != null) ...[
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                            imageUrl: 'https://image.tmdb.org/t/p/w185$path',
                            width: 42,
                            height: 63,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.movie_outlined))),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title?.isNotEmpty == true || options.isNotEmpty)
                          Text(
                            title?.isNotEmpty == true
                                ? title!
                                : '${options.length} films to choose from',
                            style: const TextStyle(
                              color: FlixieColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        if (local != null ||
                            n.watchRequestLocation?.isNotEmpty == true) ...[
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              if (local != null)
                                _PlanDetail(
                                  icon: Icons.calendar_today_outlined,
                                  text:
                                      '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${TimeOfDay.fromDateTime(local).format(context)}',
                                ),
                              if (n.watchRequestLocation?.isNotEmpty == true)
                                _PlanDetail(
                                  icon: Icons.location_on_outlined,
                                  text: n.watchRequestLocation!,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),
              ],
              if (needs) ...[
                const SizedBox(height: 10),
                const Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.schedule,
                          size: 15, color: FlixieColors.warning),
                      SizedBox(width: 6),
                      Text('Needs you',
                          style: TextStyle(
                              color: FlixieColors.warning, fontSize: 12))
                    ]),
              ],
              if (processing)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator())
              else if (needs && onAccept != null) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 4, children: [
                  FilledButton(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                          backgroundColor: FlixieColors.primary,
                          foregroundColor: Colors.white),
                      child: const Text('Accept')),
                  TextButton(onPressed: onDecline, child: const Text('Decline'))
                ]),
              ] else if (onOpen != null) ...[
                const SizedBox(height: 8),
                if (needs)
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: onOpen,
                          style: FilledButton.styleFrom(
                              backgroundColor: FlixieColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: Text(cta)))
                else
                  TextButton(onPressed: onOpen, child: Text('$cta →')),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _NotificationHeadline extends StatefulWidget {
  const _NotificationHeadline({required this.notification});
  final FlixieNotification notification;

  @override
  State<_NotificationHeadline> createState() => _NotificationHeadlineState();
}

class _NotificationHeadlineState extends State<_NotificationHeadline> {
  final TapGestureRecognizer _usernameTap = TapGestureRecognizer();

  @override
  void dispose() {
    _usernameTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final headline = notificationHeadline(n);
    final name = n.senderName;
    final id = n.senderId;
    final index = name.isEmpty ? -1 : headline.indexOf(name);
    const style = TextStyle(
        color: FlixieColors.white, fontSize: 14, fontWeight: FontWeight.w600);
    if (index < 0 || id == null || id.isEmpty) {
      return Text(headline, style: style);
    }
    _usernameTap.onTap =
        () => context.push('/friends/${Uri.encodeComponent(id)}?preview=true');
    return Text.rich(TextSpan(style: style, children: [
      TextSpan(text: headline.substring(0, index)),
      TextSpan(
          text: name,
          style: const TextStyle(color: FlixieColors.primaryText),
          recognizer: _usernameTap,
          mouseCursor: SystemMouseCursors.click),
      TextSpan(text: headline.substring(index + name.length)),
    ]));
  }
}

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 14, color: FlixieColors.light)),
          const SizedBox(width: 5),
          Flexible(
              child: Text(text,
                  style: const TextStyle(
                      color: FlixieColors.light, fontSize: 12, height: 1.4))),
        ],
      );
}
