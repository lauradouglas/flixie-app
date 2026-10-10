import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import '../../group_watch_plan_actions.dart';
import 'group_plan_components.dart';

class GroupPlanVoting extends StatelessWidget {
  const GroupPlanVoting({
    super.key,
    required this.view,
    required this.actions,
  });
  final GroupPlanViewData view;
  final GroupWatchPlanActions actions;
  GroupWatchRequest get request => view.request;
  Widget _choices(BuildContext context, GroupWatchRequest request) {
    final choices = actions.controller.choices(request);
    final count = view.activeMembers.length;
    return groupPlanSection(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What could you watch?',
            style: groupPlanSectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select every title you would happily watch.',
            style: groupPlanBody.copyWith(color: context.colors.light),
          ),
          const SizedBox(height: 16),
          ...request.candidates.map((candidate) {
            final selected = choices.contains(candidate.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _candidate(
                context,
                candidate,
                count,
                selected: selected,
                onTap: () =>
                    actions.controller.toggleChoice(request, candidate.id),
              ),
            );
          }),
          if (request.candidates.length < 5)
            groupPlanText(
              context,
              actions.processing,
              'Add another option',
              Icons.add_circle_outline_rounded,
              () => actions.addCandidate(request),
            ),
          const SizedBox(height: 8),
          groupPlanPrimary(
            context,
            actions.processing,
            'Save my picks',
            Icons.playlist_add_check_rounded,
            () => actions.saveChoices(request, choices),
          ),
        ],
      ),
    );
  }

  Widget _finalChoice(BuildContext context, GroupWatchRequest request) {
    final count = view.activeMembers.length;
    final candidates = [...request.candidates]..sort(
        (a, b) =>
            b.selectedByUserIds.length.compareTo(a.selectedByUserIds.length),
      );
    return groupPlanSection(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose the final movie',
            style: groupPlanSectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The group’s strongest matches are shown first.',
            style: groupPlanBody.copyWith(color: context.colors.light),
          ),
          const SizedBox(height: 16),
          if (request.candidates.length < 5)
            groupPlanText(
              context,
              actions.processing,
              'Add another option',
              Icons.add_circle_outline_rounded,
              () => actions.addCandidate(request),
            ),
          ...candidates.map(
            (candidate) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _candidate(
                context,
                candidate,
                count,
                trailing: FilledButton(
                  onPressed: actions.processing
                      ? null
                      : () => actions.chooseMovie(request, candidate.id),
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidate(
    BuildContext context,
    GroupWatchPlanCandidate candidate,
    int participantCount, {
    bool selected = false,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final approvals = candidate.selectedByUserIds.toSet().length;
    final unanimous = participantCount > 0 && approvals >= participantCount;
    return Material(
      color: unanimous
          ? context.colors.success.withValues(alpha: .08)
          : context.colors.background.withValues(alpha: .35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: unanimous
              ? context.colors.success
              : selected
                  ? FlixieColors.primary
                  : context.colors.tabBarBorder,
          width: unanimous || selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              groupPlanPoster(candidate.posterPath, candidate.title, 48),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.title ?? 'Movie option',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unanimous
                          ? 'Everyone’s match'
                          : '$approvals of $participantCount would watch',
                      style: TextStyle(
                        color: unanimous
                            ? context.colors.success
                            : context.colors.medium,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color:
                      selected ? context.colors.success : context.colors.medium,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return view.stage == GroupPlanStage.finalMovie
        ? _finalChoice(context, request)
        : _choices(context, request);
  }
}
