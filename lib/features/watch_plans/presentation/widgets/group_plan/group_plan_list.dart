import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import '../../controllers/group_watch_plan_controller.dart';
import '../../group_watch_plan_actions.dart';
import 'group_plan_components.dart';
import 'group_plan_card.dart';

class GroupPlanList extends StatelessWidget {
  const GroupPlanList({
    super.key,
    required this.controller,
    required this.actions,
    required this.embedded,
  });
  final GroupWatchPlanController controller;
  final GroupWatchPlanActions actions;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final plans = controller.visiblePlans;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final past in [false, true])
              FlixiePill.choice(
                label: Text(
                  past
                      ? 'Past · ${controller.pastCount}'
                      : 'Active · ${controller.activeCount}',
                ),
                selected: controller.past == past,
                onSelected: (_) => controller.showPast(past),
                showCheckmark: true,
              ),
          ],
        ),
        if (embedded && (plans.isNotEmpty || controller.past)) ...[
          const SizedBox(height: 12),
          groupPlanPrimary(
            context,
            actions.processing,
            'Make a Watch Plan',
            Icons.add_rounded,
            actions.create,
          ),
        ],
        const SizedBox(height: 16),
        if (plans.isEmpty)
          groupPlanEmpty(
            context,
            controller.past
                ? 'No past plans yet'
                : 'Plan your next movie night',
            controller.past
                ? 'Completed and closed Watch Plans will appear here.'
                : 'Choose some films, invite the group, and agree a time.',
            action: controller.past ? null : 'Make a Watch Plan',
            onTap: controller.past ? null : actions.create,
          )
        else
          ...plans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GroupPlanCard(
                view: controller.view(plan),
                onOpen: () {
                  controller.select(plan.id);
                  controller.load();
                },
              ),
            ),
          ),
      ],
    );
  }
}
