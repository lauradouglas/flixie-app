import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import '../../group_watch_plan_actions.dart';
import 'group_plan_components.dart';

class GroupPlanProposal extends StatelessWidget {
  const GroupPlanProposal({
    super.key,
    required this.view,
    required this.actions,
  });
  final GroupPlanViewData view;
  final GroupWatchPlanActions actions;
  GroupWatchRequest get request => view.request;
  Widget _proposal(BuildContext context, GroupWatchRequest request) {
    final proposal = request.activeScheduleProposal;
    if (proposal != null && request.scheduledFor?.isNotEmpty == true) {
      return _replacementProposal(context, request, proposal);
    }
    final iso = proposal?.proposedFor ?? request.proposedDate;
    final response = proposal?.responseFor(view.userId);
    final proposedByMe = proposal?.proposerId == view.userId;
    final approved = response?.status.toUpperCase() == 'ACCEPTED';
    return groupPlanSection(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal?.dateOnly == true ||
                    (proposal == null && request.proposedDateOnly)
                ? 'Does this date work?'
                : 'Does this time work?',
            style: groupPlanSectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: context.colors.secondary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  formatGroupPlanTime(
                    context,
                    iso,
                    dateOnly: proposal?.dateOnly ?? request.proposedDateOnly,
                  ),
                  style: TextStyle(
                    color: context.colors.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (proposedByMe || approved)
            groupPlanNotice(
              context,
              proposedByMe
                  ? 'Waiting for the group to respond.'
                  : 'You approved this time.',
            )
          else
            groupPlanPrimary(
              context,
              actions.processing,
              'Works for me',
              Icons.check_circle_outline_rounded,
              () => actions.approveTime(request),
            ),
          const SizedBox(height: 8),
          groupPlanOutline(
            context,
            actions.processing,
            'Suggest another time',
            Icons.edit_calendar_outlined,
            () => actions.propose(request, initialIso: iso),
          ),
          if (!proposedByMe)
            groupPlanText(
              context,
              actions.processing,
              'I can’t make it',
              Icons.person_remove_outlined,
              () => actions.declineTime(request),
            ),
        ],
      ),
    );
  }

  Widget _replacementProposal(
    BuildContext context,
    GroupWatchRequest request,
    GroupScheduleProposal proposal,
  ) {
    final response = proposal.responseFor(view.userId);
    final responseStatus = response?.status.toUpperCase() ?? 'PENDING';
    final isCreator = request.userId == view.userId;
    final allAccepted = proposal.responses.isNotEmpty &&
        proposal.responses.every(
          (item) => item.status.toUpperCase() == 'ACCEPTED',
        );
    return groupPlanSection(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review time change',
            style: groupPlanSectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your current schedule stays confirmed until everyone accepts the new time and the plan creator confirms it.',
            style: groupPlanBody.copyWith(color: context.colors.light),
          ),
          const SizedBox(height: 16),
          _timeComparison(
            context,
            label: 'Current time',
            date: request.scheduledFor,
            dateOnly: request.scheduledDateOnly,
            location: request.location,
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(height: 8),
          _timeComparison(
            context,
            label: 'Requested time',
            date: proposal.proposedFor,
            dateOnly: proposal.dateOnly,
            location: proposal.location ?? request.location,
            icon: Icons.update_rounded,
            highlighted: true,
          ),
          const SizedBox(height: 18),
          if (allAccepted && isCreator) ...[
            groupPlanNotice(
              context,
              'Everyone accepted. You have the final say.',
            ),
            const SizedBox(height: 10),
            groupPlanPrimary(
              context,
              actions.processing,
              'Confirm new time',
              Icons.check_circle_rounded,
              () => actions.finalizeReplacement(request, proposal, true),
            ),
            const SizedBox(height: 8),
            groupPlanOutline(
              context,
              actions.processing,
              'Keep current time',
              Icons.history_rounded,
              () => actions.finalizeReplacement(request, proposal, false),
            ),
          ] else if (responseStatus == 'ACCEPTED') ...[
            groupPlanNotice(
              context,
              isCreator
                  ? 'You accepted. Waiting for everyone else before you make the final decision.'
                  : 'You accepted the requested time. The current schedule stays in place for now.',
            ),
            if (isCreator) ...[
              const SizedBox(height: 8),
              groupPlanOutline(
                context,
                actions.processing,
                'Keep current time',
                Icons.history_rounded,
                () => actions.finalizeReplacement(request, proposal, false),
              ),
            ],
          ] else ...[
            groupPlanPrimary(
              context,
              actions.processing,
              'Accept new time',
              Icons.check_circle_outline_rounded,
              () => actions.approveTime(request),
            ),
            const SizedBox(height: 8),
            groupPlanOutline(
              context,
              actions.processing,
              'Keep current time',
              Icons.history_rounded,
              () => actions.keepCurrentTime(request),
            ),
          ],
          if (!allAccepted) ...[
            const SizedBox(height: 4),
            groupPlanText(
              context,
              actions.processing,
              'Suggest a different time',
              Icons.edit_calendar_outlined,
              () => actions.propose(request, initialIso: proposal.proposedFor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeComparison(
    BuildContext context, {
    required String label,
    required String? date,
    bool dateOnly = false,
    required String? location,
    required IconData icon,
    bool highlighted = false,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted
              ? FlixieColors.primary.withValues(alpha: .12)
              : context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 21,
              color: highlighted
                  ? context.colors.secondary
                  : context.colors.medium,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: highlighted
                          ? context.colors.secondary
                          : context.colors.medium,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatGroupPlanTime(context, date, dateOnly: dateOnly),
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (location?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      location!,
                      style:
                          groupPlanBody.copyWith(color: context.colors.light),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    return _proposal(context, request);
  }
}
