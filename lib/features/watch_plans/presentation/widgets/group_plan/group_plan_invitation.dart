import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import '../../group_watch_plan_actions.dart';
import 'watch_plan_movie_options.dart';
import 'group_plan_components.dart';
import 'group_plan_members.dart';
import 'group_plan_header.dart';

class GroupPlanInvitation extends StatelessWidget {
  const GroupPlanInvitation({
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
  Widget _inviteDetail(
    BuildContext context,
    GroupWatchRequest request,
    List<GroupMember> members,
  ) {
    final selected = view.selectedCandidate;
    final title =
        selected?.title ?? request.movieTitle ?? groupPlanOptionLabel(request);
    final multiple =
        request.candidates.length > 1 && request.selectedCandidateId == null;
    final location = request.location?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!multiple) ...[
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
              ],
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
                    const SizedBox(height: 7),
                    _groupPlanPill(context),
                    const SizedBox(height: 12),
                    _planFact(
                      context,
                      Icons.calendar_month_outlined,
                      groupPlanTiming(context, request),
                    ),
                    const SizedBox(height: 8),
                    _planFact(
                      context,
                      Icons.location_on_outlined,
                      location?.isNotEmpty == true
                          ? location!
                          : 'Location not set',
                    ),
                    const SizedBox(height: 8),
                    _planFact(
                      context,
                      Icons.group_outlined,
                      '${members.length} invited',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (multiple) ...[
            const SizedBox(height: 20),
            WatchPlanMovieOptions(candidates: request.candidates),
          ],
          groupPlanCreationMessage(context, request),
          Divider(height: 30, color: context.colors.tabBarBorder),
          Text(
            'Group members',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _memberRoster(context, members),
          Divider(height: 30, color: context.colors.tabBarBorder),
          _invite(context, request),
        ],
      ),
    );
  }

  Widget _memberRoster(BuildContext context, List<GroupMember> members) {
    if (members.isEmpty) {
      return Text(
        'Member details unavailable',
        style: groupPlanBody.copyWith(color: context.colors.light),
      );
    }
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      children: members
          .map(
            (member) => SizedBox(
              width: 64,
              child: Column(
                children: [
                  groupPlanAvatar(context, view.userId, member, 48),
                  const SizedBox(height: 5),
                  Text(
                    member.memberId == view.userId ? 'You' : member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _planFact(BuildContext context, IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 19, color: context.colors.primaryText),
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
  Widget _groupPlanPill(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: FlixiePill.label(label: Text('Group')),
    );
  }

  Widget _invite(BuildContext context, GroupWatchRequest request) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Will you join?',
            style: groupPlanSectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Join to choose films. You’ll approve any proposed time separately.',
            style: groupPlanBody.copyWith(color: context.colors.light),
          ),
          const SizedBox(height: 18),
          groupPlanPrimary(
            context,
            actions.processing,
            'I’m in',
            Icons.check_rounded,
            () => actions.respond(request, WatchResponseDecision.accepted),
          ),
          const SizedBox(height: 8),
          groupPlanOutline(
            context,
            actions.processing,
            'Can’t make it',
            Icons.person_remove_outlined,
            () => actions.respond(request, WatchResponseDecision.declined),
          ),
          groupPlanText(
            context,
            actions.processing,
            'Suggest another time',
            Icons.edit_calendar_outlined,
            () => actions.propose(request),
          ),
        ],
      );
  @override
  Widget build(BuildContext context) {
    return _inviteDetail(context, request, view.activeMembers);
  }
}
