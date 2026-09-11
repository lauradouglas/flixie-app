import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/watch_plan_movie_options.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class WatchRequestChatCard extends StatelessWidget {
  const WatchRequestChatCard(
      {super.key,
      required this.msg,
      this.cachedRequest,
      this.currentUserId,
      this.myStatus,
      required this.isResponding,
      this.onAccept,
      this.onDecline,
      this.onMaybe,
      required this.onTap,
      this.memberUsernames = const {},
      this.onLongPress});

  final ChatMessage msg;
  final GroupWatchRequest? cachedRequest;
  final String? currentUserId;
  final String? myStatus;
  final bool isResponding;
  final VoidCallback? onAccept, onDecline, onMaybe, onLongPress;
  final VoidCallback onTap;
  final Map<String, String> memberUsernames;
  static const _body =
      TextStyle(color: FlixieColors.light, fontSize: 14, height: 1.4);

  @override
  Widget build(BuildContext context) {
    final r = cachedRequest;
    final payload = msg.watchRequestPayload;
    final metadata = payload?['metadata'] as Map<String, dynamic>?;
    final deleted =
        metadata?['deleted'] == true || metadata?['status'] == 'deleted';
    final selected =
        r?.candidates.where((c) => c.id == r.selectedCandidateId).firstOrNull;
    final multiple =
        r != null && r.candidates.length > 1 && r.selectedCandidateId == null;
    final title = multiple
        ? '${r.candidates.length} movie options'
        : selected?.title ??
            r?.movieTitle ??
            payload?['movieTitle'] as String? ??
            metadata?['movieTitle'] as String? ??
            'Watch Plan';
    final poster = selected?.posterPath ??
        r?.moviePosterPath ??
        payload?['moviePosterUrl'] as String? ??
        metadata?['posterPath'] as String? ??
        payload?['posterPath'] as String?;
    final message = [
      r?.message,
      payload?['message'] as String?,
      metadata?['message'] as String?
    ]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .firstOrNull;
    final mine = msg.senderId == currentUserId;
    final name = mine
        ? 'You'
        : r?.requesterUsername ??
            memberUsernames[msg.senderId] ??
            msg.senderUsername ??
            'Member';
    final decision = (myStatus ??
            r?.currentUserResponse?.apiValue ??
            r?.memberStatuses
                .where((m) => m.memberId == currentUserId)
                .firstOrNull
                ?.status)
        ?.toUpperCase();
    final complete = r?.status == WatchRequestStatus.completed;
    final scheduled = r?.status == WatchRequestStatus.scheduled;
    final cancelled = r?.status == WatchRequestStatus.cancelled;
    final expired = !complete && !cancelled && r?.hasExpired == true;
    final needsReply = r != null &&
        r.canRespond &&
        !mine &&
        (decision == null || decision == 'PENDING' || decision == 'MAYBE');
    final watched = r?.memberStatuses
            .where((m) => m.watchedAt != null && m.missedAt == null)
            .length ??
        0;
    final missed =
        r?.memberStatuses.where((m) => m.missedAt != null).length ?? 0;
    final attendees =
        r?.memberStatuses.where((m) => m.status == 'ACCEPTED').toList() ?? [];
    final label = complete
        ? 'Summary ready'
        : cancelled
            ? 'Cancelled'
            : expired
                ? 'Expired'
                : needsReply
                    ? 'Your reply needed'
                    : scheduled
                        ? 'Scheduled'
                        : decision == 'DECLINED'
                            ? 'You declined'
                            : r == null
                                ? 'View Watch Plan'
                                : 'Planning together';
    final color = complete || scheduled
        ? FlixieColors.success
        : needsReply
            ? FlixieColors.warning
            : FlixieColors.light;
    final date =
        DateTime.tryParse(r?.scheduledFor ?? r?.proposedDate ?? '')?.toLocal();
    final action = complete
        ? 'View summary'
        : needsReply
            ? 'View invitation'
            : 'View plan';

    Widget button({bool decline = false}) => SizedBox(
        width: double.infinity,
        child: decline || (!complete && !needsReply)
            ? OutlinedButton(
                onPressed: isResponding
                    ? null
                    : decline
                        ? onDecline
                        : onTap,
                style: OutlinedButton.styleFrom(
                    foregroundColor: FlixieColors.light,
                    side: const BorderSide(color: FlixieColors.tabBarBorder),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: Text(decline ? 'Can’t make it' : action,
                    textAlign: TextAlign.center))
            : FilledButton(
                onPressed: isResponding ? null : onTap,
                style: FilledButton.styleFrom(
                    backgroundColor: FlixieColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: Text(action, textAlign: TextAlign.center)));

    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              color: FlixieColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 19)),
      const SizedBox(height: 9),
      _fact(
          complete || scheduled
              ? Icons.check_circle
              : needsReply
                  ? Icons.schedule
                  : Icons.movie_outlined,
          label,
          color),
      const SizedBox(height: 8),
      if (complete) ...[
        const Text('Everyone has responded.', style: _body),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _count(Icons.people_alt, '$watched watched', FlixieColors.success),
          _count(Icons.person_outline, '$missed couldn’t make it',
              FlixieColors.warning),
        ]),
      ] else if (!cancelled && !expired) ...[
        if (date != null)
          Text(
              '${MaterialLocalizations.of(context).formatMediumDate(date)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
              style: _body)
        else if (r != null)
          const Text('Date not set yet', style: _body),
        if (r?.location?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 7),
          _fact(Icons.location_on_outlined, r!.location!, FlixieColors.light),
        ],
        if (r != null) ...[
          const SizedBox(height: 9),
          Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (scheduled && attendees.isNotEmpty)
                  SizedBox(
                      width: 26.0 * attendees.take(3).length + 6,
                      height: 32,
                      child: Stack(children: [
                        for (var i = 0; i < attendees.take(3).length; i++)
                          Positioned(
                              left: i * 26.0,
                              child: ProfileAvatarView(
                                  avatar: attendees[i].avatar,
                                  fallbackText: (attendees[i].username ?? '?')
                                          .characters
                                          .firstOrNull ??
                                      '?',
                                  fallbackColor: FlixieColors.primaryText,
                                  size: 32))
                      ])),
                Text(
                    '${r.acceptedCount} going${needsReply ? ' · Waiting for you' : ''}',
                    style: _body),
              ]),
        ],
      ],
    ]);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ProfileAvatarView(
                avatar: r?.requesterAvatar,
                fallbackText: name.characters.firstOrNull ?? '?',
                fallbackColor: FlixieColors.primaryText,
                size: 32),
            const SizedBox(width: 9),
            Flexible(
                child: Text(name,
                    style: const TextStyle(
                        color: FlixieColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14))),
            const SizedBox(width: 8),
            Text(
                MaterialLocalizations.of(context).formatTimeOfDay(
                    TimeOfDay.fromDateTime(msg.createdAt.toLocal())),
                style: _body),
          ]),
          const SizedBox(height: 8),
          Material(
              color: FlixieColors.tabBarBackgroundFocused,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: FlixieColors.primary.withValues(alpha: .6))),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: deleted ? null : onTap,
                onLongPress: onLongPress,
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: deleted
                        ? const Text('This Watch Plan was deleted.',
                            style: _body)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                LayoutBuilder(builder: (context, constraints) {
                                  final stack = constraints.maxWidth < 280 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(1) >
                                          1.4;
                                  if (multiple) return details;
                                  final art = multiple
                                      ? WatchPlanPosterStack(posters: [
                                          for (final c in r.candidates.take(3))
                                            WatchPlanPoster(path: c.posterPath, title: c.title, width: stack ? 72 : 82),
                                        ])
                                      : _poster(poster, stack ? 72 : 82);
                                  return stack
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              art,
                                              const SizedBox(height: 12),
                                              details
                                            ])
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              art,
                                              const SizedBox(width: 14),
                                              Expanded(child: details)
                                            ]);
                                }),
                                if (multiple) ...[
                                  const SizedBox(height: 14),
                                  WatchPlanMovieOptions(
                                      candidates: r.candidates),
                                ],
                                if (message != null) ...[
                                  const SizedBox(height: 12),
                                  Text('“$message”', style: _body)
                                ],
                                const SizedBox(height: 14),
                                if (isResponding)
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: LinearProgressIndicator()),
                                if (needsReply && onDecline != null)
                                  LayoutBuilder(
                                      builder: (context, constraints) =>
                                          constraints.maxWidth < 340 ||
                                                  MediaQuery.textScalerOf(
                                                              context)
                                                          .scale(1) >
                                                      1.2
                                              ? Column(children: [
                                                  button(),
                                                  const SizedBox(height: 8),
                                                  button(decline: true)
                                                ])
                                              : Row(children: [
                                                  Expanded(child: button()),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                      child:
                                                          button(decline: true))
                                                ]))
                                else
                                  button(),
                              ])),
              )),
        ]));
  }

  Widget _fact(IconData icon, String text, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: _body.copyWith(color: color))),
      ]);
  Widget _count(IconData icon, String text, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: _body.copyWith(color: color))),
      ]);
  Widget _poster(String? path, double width) {
    final fallback = Container(
        color: FlixieColors.tabBarBackground,
        child: const Center(
            child: Icon(Icons.movie_outlined, color: FlixieColors.light)));
    return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
            width: width,
            height: width * 1.48,
            child: path == null || path.isEmpty
                ? fallback
                : CachedNetworkImage(
                    imageUrl: path.startsWith('http')
                        ? path
                        : 'https://image.tmdb.org/t/p/w185$path',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => fallback,
                    errorWidget: (_, __, ___) => fallback)));
  }
}
