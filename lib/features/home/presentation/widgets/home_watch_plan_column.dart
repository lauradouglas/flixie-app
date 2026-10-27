import 'home_tablet_layout.dart';
import 'package:flutter/material.dart';
import '../models/home_watch_plan_state.dart';
import 'home_watch_plan_card.dart';

/// Home's wide companion column previews the highest-priority plan; the
/// section's See all action retains access to the remaining plans.
class HomeWatchPlanColumn extends StatelessWidget {
  const HomeWatchPlanColumn(
      {super.key, required this.states, required this.onOpen});
  final List<HomeWatchPlanState> states;
  final ValueChanged<HomeWatchPlanState> onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: HomeTabletLayout.active(context) ? 12 : 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var index = 0;
              index <
                  (HomeTabletLayout.active(context)
                      ? states.take(1).length
                      : states.length);
              index++) ...[
            if (index > 0) const SizedBox(height: 12),
            HomeWatchPlanCard(
                state: states[index], onOpen: () => onOpen(states[index])),
          ],
        ]),
      );
}
