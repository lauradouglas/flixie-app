import 'package:flutter/material.dart';
import '../models/home_watch_plan_state.dart';
import 'home_watch_plan_card.dart';

/// Tablet Home shows every preview vertically in the page's own scroll view.
class HomeWatchPlanColumn extends StatelessWidget {
  const HomeWatchPlanColumn(
      {super.key, required this.states, required this.onOpen});
  final List<HomeWatchPlanState> states;
  final ValueChanged<HomeWatchPlanState> onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var index = 0; index < states.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            HomeWatchPlanCard(
                state: states[index], onOpen: () => onOpen(states[index])),
          ],
        ]),
      );
}
