import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';

class HomeWatchPlanCard extends StatelessWidget {
  const HomeWatchPlanCard({
    super.key,
    required this.state,
    required this.onOpen,
  });

  final HomeWatchPlanState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final chosen = plan.candidates
        .where((candidate) => candidate.id ==
            (plan.selectedCandidateId ?? plan.proposedCandidateId))
        .firstOrNull;
    final suggestions = chosen != null
        ? [chosen]
        : plan.selectedCandidateId != null
            ? plan.candidates.where((c) => c.id == plan.selectedCandidateId).toList()
            : plan.candidates.take(3).toList();
    final tone = state.colorRole.color;
    // The brand purple works for borders and controls, but compact status copy
    // needs the contrast-safe text token against this dark card surface.
    final statusTextColor =
        tone == FlixieColors.primary ? FlixieColors.primaryText : tone;
    return Semantics(
      button: true,
      label:
          '${state.eyebrow}. ${state.title}. ${state.supportingText}. ${state.actionLabel}',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    tone.withValues(alpha: .10),
                    FlixieColors.surfaceElevated,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tone.withValues(alpha: .75)),
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 390 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.15;
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(state.statusIcon,
                                color: statusTextColor, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(state.eyebrow,
                                  maxLines: 2,
                                  style: TextStyle(
                                      color: statusTextColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .8)),
                            ),
                          ]),
                      const SizedBox(height: 5),
                      Text(state.title,
                          maxLines: narrow ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(state.supportingText,
                          maxLines: narrow ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 13,
                              height: 1.25)),
                    ],
                  );
                  final button = FilledButton(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      backgroundColor: tone,
                      foregroundColor: state.colorRole.foreground,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(state.actionLabel,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                  final leading = suggestions.isEmpty
                      ? WatchPlanPoster(
                          path: plan.movie?.posterPath,
                          title: state.title,
                          width: 58,
                        )
                      : SizedBox(
                          width: 58 + (suggestions.length - 1) * 9.0,
                          height: 87 + (suggestions.length - 1) * 9.0,
                          child: Stack(children: [
                            for (var i = suggestions.length - 1; i >= 0; i--)
                              Positioned(
                                left: i * 9.0,
                                top: i * 9.0,
                                child: WatchPlanPoster(
                                  path: suggestions[i].posterPath,
                                  title: suggestions[i].title,
                                  width: 58,
                                ),
                              ),
                          ]),
                        );
                  if (narrow) {
                    return Column(children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            leading,
                            const SizedBox(width: 12),
                            Expanded(child: details)
                          ]),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: button),
                    ]);
                  }
                  return Row(children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    button,
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }


}

class HomeWatchPlanEmptyCard extends StatelessWidget {
  const HomeWatchPlanEmptyCard({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Semantics(
          container: true,
          label:
              'Watch together. Plan your next watch. Pick movies and decide with friends.',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.surfaceElevated.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: FlixieColors.primary.withValues(alpha: .55),
              ),
            ),
            child: Column(
              children: [
                const Row(children: [
                  SizedBox(
                    width: 58,
                    height: 87,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x337C4DFF),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Icon(Icons.movie_filter_rounded,
                          color: FlixieColors.primary, size: 28),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WATCH TOGETHER',
                            style: TextStyle(
                                color: FlixieColors.primaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .8)),
                        SizedBox(height: 5),
                        Text('Plan your next watch',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Pick movies and decide with friends.',
                            style: TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 13,
                                height: 1.25)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: Colors.white,
                    backgroundColor: FlixieColors.primary,
                  ),
                  child: const Text('Make a plan'),
                ),
              ],
            ),
          ),
        ),
      );
}
