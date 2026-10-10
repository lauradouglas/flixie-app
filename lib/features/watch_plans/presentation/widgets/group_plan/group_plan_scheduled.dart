import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import '../../group_watch_plan_actions.dart';
import 'group_plan_components.dart';
import 'group_plan_members.dart';
import 'group_plan_header.dart';

class GroupPlanScheduled extends StatelessWidget {
  const GroupPlanScheduled({
    super.key,
    required this.view,
    required this.actions,
    this.embedded = false,
    required this.onBack,
  });
  final GroupPlanViewData view;
  final GroupWatchPlanActions actions;
  final bool embedded;
  final VoidCallback onBack;
  GroupWatchRequest get request => view.request;
  Widget _scheduledDetail(
    BuildContext context,
    GroupWatchRequest request,
    List<GroupMember> members,
  ) {
    final selected = view.selectedCandidate;
    final title =
        selected?.title ?? request.movieTitle ?? groupPlanOptionLabel(request);
    final location = request.location?.trim();
    final date = DateTime.tryParse(request.scheduledFor ?? '')?.toLocal();
    final canUpdate =
        request.userId == view.userId || request.canScheduleFor(view.userId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              groupPlanMovieLink(
                context,
                view,
                request,
                groupPlanDetailPoster(
                  context,
                  embedded,
                  onBack,
                  selected?.posterPath ?? request.moviePosterPath,
                  title,
                  96,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    groupPlanMovieLink(
                      context,
                      view,
                      request,
                      Text(
                        title,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      view.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: groupPlanBody.copyWith(
                        color: context.colors.light,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _scheduleFact(
                      context,
                      Icons.calendar_month_outlined,
                      formatGroupPlanTime(
                        context,
                        request.scheduledFor,
                        dateOnly: request.scheduledDateOnly,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _scheduleFact(
                      context,
                      Icons.location_on_outlined,
                      location?.isNotEmpty == true
                          ? location!
                          : 'Location not set',
                    ),
                    const SizedBox(height: 10),
                    _scheduledPill(context),
                  ],
                ),
              ),
            ],
          ),
          groupPlanCreationMessage(context, request),
          Divider(height: 30, color: context.colors.tabBarBorder),
          Text(
            'Confirmed attendees (${members.length})',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  groupPlanAvatar(context, view.userId, member, 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      member.memberId == view.userId
                          ? 'You'
                          : member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.colors.success,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          groupPlanPrimary(
            context,
            actions.processing,
            'Add to calendar',
            Icons.event_available_rounded,
            date == null
                ? null
                : () => WatchCalendarService.addScheduledWatch(
                      title: request.movieTitle ?? 'Group watch',
                      scheduledFor: date,
                      dateOnly: request.scheduledDateOnly,
                      location: request.location,
                      note: 'With ${view.groupName}',
                    ),
          ),
          if (canUpdate) ...[
            const SizedBox(height: 8),
            groupPlanOutline(
              context,
              actions.processing,
              'Update date or time',
              Icons.schedule_rounded,
              () => actions.propose(request, initialIso: request.scheduledFor),
            ),
          ],
          if (request.userId == view.userId)
            groupPlanText(
              context,
              actions.processing,
              'Change movie options',
              Icons.playlist_add_rounded,
              () => actions.reopenChoices(request),
            ),
          if (request.userId != view.userId &&
              !request.hasLoggedFor(view.userId) &&
              !request.hasMissedFor(view.userId))
            groupPlanText(
              context,
              actions.processing,
              'Leave this screening',
              Icons.person_remove_outlined,
              () => actions.respond(request, WatchResponseDecision.declined),
            ),
          const SizedBox(height: 16),
          if (request.hasMissedFor(view.userId))
            groupPlanNotice(
              context,
              'You didn’t make it. No watch entry was added.',
            )
          else if (request.hasLoggedFor(view.userId) ||
              request.hasCurrentUserCompleted == true)
            groupPlanNotice(
              context,
              'Your watch has been logged. Waiting for the rest of the group.',
            )
          else if (request.canCompleteFor(view.userId)) ...[
            groupPlanOutline(
              context,
              actions.processing,
              'Already watched? Log your watch',
              Icons.check_circle_outline,
              () => actions.logWatch(request),
            ),
            const SizedBox(height: 6),
            Text(
              'Went early? Record when you watched, your rating and an optional review.',
              style: groupPlanBody.copyWith(color: context.colors.light),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scheduleFact(BuildContext context, IconData icon, String label) =>
      Row(
        children: [
          Icon(icon, size: 19, color: context.colors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: groupPlanBody.copyWith(color: context.colors.light),
            ),
          ),
        ],
      );
  Widget _scheduledPill(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: FlixiePill.label(
        label: Text('Scheduled'),
        avatar: Icon(Icons.check_circle_rounded),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _scheduledDetail(context, request, view.activeMembers);
  }
}
