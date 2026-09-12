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
    final selected = plan.candidates
        .where((candidate) => candidate.id == plan.selectedCandidateId)
        .firstOrNull;
    final suggestions =
        selected != null ? [selected] : plan.candidates.take(3).toList();
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
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    tone.withValues(alpha: .08),
                    FlixieColors.surface,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tone.withValues(alpha: .25)),
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.15;
                  final status = state.eyebrow.isEmpty
                      ? ''
                      : '${state.eyebrow[0].toUpperCase()}${state.eyebrow.substring(1).toLowerCase()}';
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                    color: statusTextColor,
                                    shape: BoxShape.circle),
                                child: Icon(state.statusIcon,
                                    color: FlixieColors.background, size: 17)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(status,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2)),
                                  const SizedBox(height: 4),
                                  Text(state.title,
                                      style: const TextStyle(
                                          color: FlixieColors.light,
                                          fontSize: 12,
                                          height: 1.25)),
                                ])),
                          ]),
                      const SizedBox(height: 8),
                      Text(state.supportingText,
                          style: const TextStyle(
                              color: FlixieColors.light,
                              fontSize: 12,
                              height: 1.35)),
                    ],
                  );
                  final button = FilledButton(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      backgroundColor: state.requiresAttention
                          ? statusTextColor
                          : tone.withValues(alpha: .24),
                      foregroundColor: state.requiresAttention
                          ? FlixieColors.background
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(state.actionLabel),
                  );
                  final leading = suggestions.isEmpty
                      ? WatchPlanPoster(
                          path: plan.movie?.posterPath,
                          title: state.title,
                          width: 68)
                      : SizedBox(
                          width: 68 + (suggestions.length - 1) * 6.0,
                          height: 102 + (suggestions.length - 1) * 6.0,
                          child: Stack(children: [
                            for (var i = suggestions.length - 1; i >= 0; i--)
                              Positioned(
                                  left: i * 6.0,
                                  top: i * 6.0,
                                  child: WatchPlanPoster(
                                      path: suggestions[i].posterPath,
                                      title: suggestions[i].title,
                                      width: 68)),
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
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              details,
                              const SizedBox(height: 12),
                              SizedBox(width: double.infinity, child: button),
                            ])),
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
              borderRadius: BorderRadius.circular(12),
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
                                color: FlixieColors.light,
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
