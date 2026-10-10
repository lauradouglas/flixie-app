import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import '../../group_watch_plan_actions.dart';
import 'group_watch_plan_recap.dart';
import 'group_plan_components.dart';
import 'group_plan_header.dart';
import 'group_plan_invitation.dart';
import 'group_plan_scheduled.dart';
import 'group_plan_voting.dart';
import 'group_plan_proposal.dart';
import 'group_plan_progress.dart';

class GroupPlanDetail extends StatelessWidget {
  const GroupPlanDetail({
    super.key,
    required this.view,
    required this.actions,
    this.embedded = false,
    this.groupId,
    required this.onBack,
  });
  final GroupPlanViewData view;
  final GroupWatchPlanActions actions;
  final bool embedded;
  final String? groupId;
  final VoidCallback onBack;
  GroupWatchRequest get request => view.request;
  Widget _detail(BuildContext context, GroupWatchRequest request) {
    final stage = groupPlanState(context, view).stage;
    if (stage == GroupPlanStage.declined) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GroupPlanHeader(
            view: view,
            embedded: embedded,
            groupId: groupId,
            onBack: onBack,
          ),
          const SizedBox(height: 20),
          groupPlanMessage(
            context,
            actions.processing,
            'You left this screening',
            'You won’t receive further updates or reminders for this Watch Plan.',
          ),
          if (request.isActive)
            groupPlanOutline(
              context,
              actions.processing,
              'Rejoin plan',
              Icons.person_add_alt_rounded,
              () => actions.respond(request, WatchResponseDecision.accepted),
            ),
        ],
      );
    }
    if (stage == GroupPlanStage.invite) {
      return GroupPlanInvitation(
        view: view,
        actions: actions,
        embedded: embedded,
        onBack: onBack,
      );
    }
    if (stage == GroupPlanStage.recap) return _recap(context, request);
    if (stage == GroupPlanStage.scheduled) {
      return GroupPlanScheduled(
        view: view,
        actions: actions,
        embedded: embedded,
        onBack: onBack,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroupPlanHeader(
          view: view,
          embedded: embedded,
          groupId: groupId,
          onBack: onBack,
        ),
        groupPlanCreationMessage(context, request),
        Divider(height: 30, color: context.colors.tabBarBorder),
        _actionCard(context, request),
        if (request.userId == view.userId &&
            request.selectedCandidateId != null &&
            request.isActive)
          groupPlanText(
            context,
            actions.processing,
            'Change movie options',
            Icons.playlist_add_rounded,
            () => actions.reopenChoices(request),
          ),
        Divider(height: 30, color: context.colors.tabBarBorder),
        GroupPlanProgress(
          view: view,
        ),
      ],
    );
  }

  Widget _actionCard(BuildContext context, GroupWatchRequest request) =>
      switch (groupPlanState(context, view).stage) {
        GroupPlanStage.invite => GroupPlanInvitation(
            view: view,
            actions: actions,
            embedded: embedded,
            onBack: onBack,
          ),
        GroupPlanStage.picking => GroupPlanVoting(
            view: view,
            actions: actions,
          ),
        GroupPlanStage.finalMovie => GroupPlanVoting(
            view: view,
            actions: actions,
          ),
        GroupPlanStage.waitingMovie => groupPlanMessage(
            context,
            actions.processing,
            'Waiting for the final movie',
            'The plan owner will choose from the group’s saved picks.',
          ),
        GroupPlanStage.chooseTime => groupPlanMessage(
            context,
            actions.processing,
            'Choose a date',
            'The movie is set. Propose when and where the group should watch.',
            action: 'Propose a date',
            icon: Icons.calendar_month_rounded,
            onTap: () => actions.propose(request),
          ),
        GroupPlanStage.proposal => GroupPlanProposal(
            view: view,
            actions: actions,
          ),
        GroupPlanStage.scheduled => GroupPlanScheduled(
            view: view,
            actions: actions,
            embedded: embedded,
            onBack: onBack,
          ),
        GroupPlanStage.postWatch => _postWatch(context, request),
        GroupPlanStage.recap => _recap(context, request),
        GroupPlanStage.declined => groupPlanMessage(
            context,
            actions.processing,
            'You left this screening',
            'You won’t receive further updates or reminders for this Watch Plan.',
          ),
        GroupPlanStage.closed => groupPlanMessage(
            context,
            actions.processing,
            request.statusLabel,
            'This Watch Plan is no longer active.',
          ),
      };
  Widget _postWatch(BuildContext context, GroupWatchRequest request) =>
      groupPlanSection(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How did ${request.movieTitle ?? 'it'} go?',
              style: groupPlanSectionTitle.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Log your viewing, or let the group know you couldn’t make it.',
              style: groupPlanBody.copyWith(color: context.colors.light),
            ),
            const SizedBox(height: 18),
            if (request.hasMissedFor(view.userId))
              groupPlanNotice(
                context,
                'You didn’t make it. No watch entry was added.',
              )
            else if (request.hasCurrentUserCompleted == true ||
                request.hasLoggedFor(view.userId))
              groupPlanNotice(context, 'Your watch has been logged.')
            else ...[
              groupPlanPrimary(
                context,
                actions.processing,
                'Log your watch',
                Icons.check_rounded,
                () => actions.logWatch(request),
              ),
              const SizedBox(height: 8),
              groupPlanOutline(
                context,
                actions.processing,
                'I didn’t make it',
                Icons.event_busy_outlined,
                () => actions.missed(request),
              ),
            ],
          ],
        ),
      );
  Widget _recap(BuildContext context, GroupWatchRequest request) =>
      GroupWatchPlanRecap(
        request: request,
        currentUserId: view.userId,
        members: view.members,
        onOpenChat: () =>
            context.go('/groups/${groupId ?? request.groupId}?tab=chat'),
      );
  @override
  Widget build(BuildContext context) {
    return _detail(context, request);
  }
}
