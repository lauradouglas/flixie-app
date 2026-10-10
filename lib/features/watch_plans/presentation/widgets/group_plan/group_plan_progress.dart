import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import 'group_plan_components.dart';
import 'group_plan_members.dart';

class GroupPlanProgress extends StatelessWidget {
  const GroupPlanProgress({
    super.key,
    required this.view,
  });
  final GroupPlanViewData view;
  GroupWatchRequest get request => view.request;
  Widget _progress(
    BuildContext context,
    GroupWatchRequest request,
    List<GroupMember> members,
  ) {
    final proposal = request.activeScheduleProposal;
    final stage = groupPlanState(context, view).stage;
    final isScheduleResponse =
        stage == GroupPlanStage.proposal || stage == GroupPlanStage.scheduled;
    return groupPlanSection(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isScheduleResponse ? 'Group responses' : 'Group progress',
                  style: groupPlanSectionTitle.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              if (!isScheduleResponse)
                Text(
                  '${members.length} ${members.length == 1 ? 'person' : 'people'}',
                  style: TextStyle(
                    color: context.colors.medium,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...members.map((member) {
            final planResponse = request.memberStatuses
                .where((item) => item.memberId == member.memberId)
                .firstOrNull;
            final timeResponse = proposal?.responseFor(member.memberId);
            final progress = _progressLabel(
              context,
              request,
              member,
              planResponse,
              timeResponse,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LayoutBuilder(builder: (context, constraints) {
                final name = Text(
                  member.memberId == view.userId ? 'You' : member.displayName,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700),
                );
                final status = Text(progress.$1,
                    style: TextStyle(
                        color: progress.$2,
                        fontSize: 13,
                        fontWeight: FontWeight.w700));
                final icon = Icon(progress.$3, color: progress.$2, size: 22);
                final compact = constraints.maxWidth < 380 ||
                    MediaQuery.textScalerOf(context).scale(13) > 17;
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      groupPlanAvatar(context, view.userId, member, 42),
                      const SizedBox(width: 10),
                      if (compact)
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              name,
                              const SizedBox(height: 4),
                              Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [status, icon]),
                            ]))
                      else ...[
                        Expanded(child: name),
                        const SizedBox(width: 8),
                        Flexible(child: status),
                        const SizedBox(width: 8),
                        icon,
                      ],
                    ]);
              }),
            );
          }),
        ],
      ),
    );
  }

  (String, Color, IconData) _progressLabel(
    BuildContext context,
    GroupWatchRequest request,
    GroupMember member,
    GroupRequestMemberStatus? response,
    GroupScheduleProposalResponse? timeResponse,
  ) {
    final stage = groupPlanState(context, view).stage;
    if (stage == GroupPlanStage.scheduled) {
      return ('Confirmed', context.colors.success, Icons.check_circle_rounded);
    }
    if (stage == GroupPlanStage.proposal) {
      return switch (timeResponse?.status.toUpperCase()) {
        'ACCEPTED' => (
            'Accepted',
            context.colors.success,
            Icons.check_circle_rounded,
          ),
        'DECLINED' => (
            'Can’t make it',
            context.colors.warning,
            Icons.cancel_outlined,
          ),
        _ => ('Pending', context.colors.warning, Icons.schedule_rounded),
      };
    }
    if (response?.missedAt != null) {
      return (
        'Didn’t make it',
        context.colors.medium,
        Icons.event_busy_outlined,
      );
    }
    if (response?.watchedAt != null) {
      return ('Watched', context.colors.success, Icons.check_circle_rounded);
    }
    if (stage == GroupPlanStage.postWatch) {
      return (
        'Still to respond',
        context.colors.medium,
        Icons.schedule_rounded,
      );
    }
    if (timeResponse != null) {
      return switch (timeResponse.status.toUpperCase()) {
        'ACCEPTED' => (
            'Time approved',
            context.colors.success,
            Icons.check_circle_rounded,
          ),
        'DECLINED' => (
            'Needs another time',
            context.colors.warning,
            Icons.edit_calendar_outlined,
          ),
        _ => ('Time pending', context.colors.medium, Icons.schedule_rounded),
      };
    }
    if (member.memberId == request.userId) {
      return ('Plan owner', context.colors.success, Icons.check_circle_rounded);
    }
    return switch (response?.status) {
      'ACCEPTED' => (
          'Joined',
          context.colors.success,
          Icons.check_circle_rounded,
        ),
      'DECLINED' => (
          'Not attending',
          context.colors.medium,
          Icons.cancel_outlined,
        ),
      'MAYBE' => ('Maybe', context.colors.warning, Icons.help_outline_rounded),
      _ => ('Pending', context.colors.medium, Icons.schedule_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _progress(context, request, view.activeMembers);
  }
}
