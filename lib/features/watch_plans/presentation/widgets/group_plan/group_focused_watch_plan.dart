import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/request_poster_placeholder.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_plan_activity.dart';
import 'package:flixie_app/models/group_watch_request.dart';

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
    required this.movieChoicesBuilder,
    required this.activity,
    required this.completedContent,
    required this.postWatchContent,
    required this.onChangeMovie,
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
  final WidgetBuilder movieChoicesBuilder;
  final Widget activity;
  final Widget completedContent;
  final Widget postWatchContent;
  final VoidCallback onChangeMovie;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        surface(
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
                    Row(children: [
                      ProfileAvatarView(
                        avatar: req.requesterAvatar,
                        fallbackText:
                            (req.requesterUsername ?? '?')[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text('With ${req.requesterUsername ?? 'the group'}',
                          style: const TextStyle(
                              color: FlixieColors.light, fontSize: 14)),
                    ]),
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
                          Row(children: [
                            ProfileAvatarView(
                              avatar: req.requesterAvatar,
                              fallbackText: (req.requesterUsername ?? '?')[0]
                                  .toUpperCase(),
                              fallbackColor: FlixieColors.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'With ${req.requesterUsername ?? 'the group'}',
                                  style: const TextStyle(
                                      color: FlixieColors.light, fontSize: 14)),
                            ),
                          ]),
                          if (proposedDate.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(proposedDate,
                                style: const TextStyle(
                                    color: FlixieColors.secondary,
                                    fontWeight: FontWeight.w800)),
                          ],
                          if (isMyRequest &&
                              req.status != WatchRequestStatus.completed) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: isProcessing ? null : onChangeMovie,
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Change movie'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (needsReply)
          surface(child: responseActions)
        else if (canManage)
          surface(child: manageActions),
        if (needsReply || canManage) const SizedBox(height: 12),
        if (req.status == WatchRequestStatus.completed) ...[
          surface(
            child: GroupCompletedWatchSummary(req: req),
          ),
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
                                  : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ProfileAvatarView(
                        avatar: member.avatar,
                        fallbackText: (member.username ?? '?')[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 42,
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
            Text(
                '${accepted.length + 1} accepted · ${invitees.length - accepted.length - declined.length} waiting${declined.isEmpty ? '' : ' · ${declined.length} declined'}',
                style: const TextStyle(
                    color: FlixieColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        surface(
          child: activity,
        ),
      ],
    );
  }

  Widget _poster(String? posterUrl) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 105,
          height: 158,
          child: posterUrl == null
              ? const RequestPosterPlaceholder()
              : CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover),
        ),
      );
}
