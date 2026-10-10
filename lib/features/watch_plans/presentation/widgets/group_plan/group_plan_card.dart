import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../group_watch_plan_selection.dart';
import '../shared/watch_plan_components.dart';
import 'group_plan_components.dart';
import 'group_plan_members.dart';

class GroupPlanCard extends StatelessWidget {
  const GroupPlanCard({super.key, required this.view, required this.onOpen});
  final GroupPlanViewData view;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final request = view.request;
    final state = groupPlanState(context, view);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onOpen,
      child: groupPlanSurface(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (request.selectedCandidateId == null &&
                request.candidates.length > 1)
              WatchPlanPosterStack(
                posters: [
                  for (final c in request.candidates.take(3))
                    WatchPlanPoster(
                      path: c.posterPath,
                      title: c.title,
                      width: 70,
                    ),
                ],
              )
            else
              groupPlanPoster(request.moviePosterPath, request.movieTitle, 70),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  groupPlanStatus(context, state),
                  const SizedBox(height: 7),
                  Text(
                    request.movieTitle ?? groupPlanOptionLabel(request),
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    view.groupName,
                    style: TextStyle(
                      color: context.colors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    groupPlanTiming(context, request),
                    style: groupPlanBody.copyWith(color: context.colors.light),
                  ),
                  if (request.isActive) ...[
                    const SizedBox(height: 3),
                    Text(
                      groupPlanReplyLabel(view),
                      style: groupPlanBody.copyWith(
                        color: context.colors.light,
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  groupPlanAvatars(
                    context,
                    view.userId,
                    view.activeMembers,
                    34,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Icon(
                Icons.chevron_right_rounded,
                color: context.colors.medium,
              ),
            ),
          ],
        ),
        border: state.color.withValues(alpha: .45),
      ),
    );
  }
}

String groupPlanReplyLabel(GroupPlanViewData view) {
  final request = view.request;
  final members = view.members;
  if (members.isEmpty) return '${request.responseCount} replied';
  final repliedIds = request.memberStatuses
      .where(
        (item) =>
            item.status == 'ACCEPTED' ||
            item.status == 'DECLINED' ||
            item.status == 'MAYBE',
      )
      .map((item) => item.memberId)
      .toSet()
    ..add(request.userId);
  final replied =
      members.where((member) => repliedIds.contains(member.memberId)).length;
  return '$replied of ${members.length} replied';
}
