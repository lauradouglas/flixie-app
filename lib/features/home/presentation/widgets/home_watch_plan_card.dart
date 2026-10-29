import 'home_tablet_layout.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';

// Keep the chosen teal surface for waiting/logged cards; other statuses retain their original tint.
Color _watchTogetherSurface(BuildContext context, WatchPlanColorRole role) {
  if (role == WatchPlanColorRole.waiting) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF153034)
        : const Color(0xFFEDF5F4);
  }
  return Color.alphaBlend(
      context.colors.adapt(role.color).withValues(alpha: .08),
      context.colors.surface);
}

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
    final compact = HomeTabletLayout.active(context);
    final posterWidth = compact ? 50.0 : 68.0;
    final plan = state.plan;
    final selected = plan.candidates
        .where((candidate) => candidate.id == plan.selectedCandidateId)
        .firstOrNull;
    final suggestions =
        selected != null ? [selected] : plan.candidates.take(3).toList();
    final tone = context.colors.adapt(state.colorRole.color);
    // The brand purple works for borders and controls, but compact status copy
    // needs the contrast-safe text token against this dark card surface.
    final statusTextColor =
        tone == FlixieColors.primary ? context.colors.primaryText : tone;
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
                  color: _watchTogetherSurface(context, state.colorRole),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tone.withValues(alpha: .25)),
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  final narrow = (!compact && constraints.maxWidth < 300) ||
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
                                    color: context.colors.background,
                                    size: 17)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(status,
                                      style: TextStyle(
                                          color: context.colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2)),
                                  const SizedBox(height: 4),
                                  Text(state.title,
                                      style: TextStyle(
                                          color: context.colors.light,
                                          fontSize: 12,
                                          height: 1.25)),
                                ])),
                          ]),
                      const SizedBox(height: 8),
                      Text(state.supportingText,
                          style: TextStyle(
                              color: context.colors.light,
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
                          ? context.colors.background
                          : context.colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: compact
                          ? const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)
                          : FlixieTypography.button,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(state.actionLabel),
                  );
                  final leading = suggestions.isEmpty
                      ? WatchPlanPoster(
                          path: plan.movie?.posterPath,
                          title: state.title,
                          width: posterWidth)
                      : SizedBox(
                          width: posterWidth + (suggestions.length - 1) * 6.0,
                          height: posterWidth * 1.5 +
                              (suggestions.length - 1) * 6.0,
                          child: Stack(children: [
                            for (var i = suggestions.length - 1; i >= 0; i--)
                              Positioned(
                                  left: i * 6.0,
                                  top: i * 6.0,
                                  child: WatchPlanPoster(
                                      path: suggestions[i].posterPath,
                                      title: suggestions[i].title,
                                      width: posterWidth)),
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
              color: context.colors.surfaceElevated.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlixieColors.primary.withValues(alpha: .55),
              ),
            ),
            child: Column(
              children: [
                Row(children: [
                  const SizedBox(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WATCH TOGETHER',
                            style: TextStyle(
                                color: context.colors.primaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .8)),
                        const SizedBox(height: 5),
                        Text('Plan your next watch',
                            style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Pick movies and decide with friends.',
                            style: TextStyle(
                                color: context.colors.light,
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

/// Portrait's horizontal plan preview keeps contextual actions from the live plan.
class PortraitHomeWatchPlanCard extends StatelessWidget {
  const PortraitHomeWatchPlanCard(
      {super.key,
      required this.state,
      required this.onOpen,
      required this.onCreate});
  final HomeWatchPlanState state;
  final VoidCallback onOpen, onCreate;

  @override
  Widget build(BuildContext context) {
    final selected = state.plan.candidates
        .where((c) => c.id == state.plan.selectedCandidateId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
                onTap: onOpen,
                child: WatchPlanPoster(
                    path: selected?.posterPath ?? state.plan.movie?.posterPath,
                    title: state.title,
                    width: 68)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(state.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(state.eyebrow,
                      style: TextStyle(
                          fontSize: 12, color: context.colors.primaryText)),
                  const SizedBox(height: 4),
                  Text(state.supportingText,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: context.colors.light)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    FilledButton(
                        onPressed: onOpen,
                        style: FilledButton.styleFrom(
                            backgroundColor: state.requiresAttention
                                ? context.colors.warning
                                : null,
                            foregroundColor: state.requiresAttention
                                ? context.colors.background
                                : null,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        child: Text(state.actionLabel)),
                    OutlinedButton.icon(
                        onPressed: onCreate,
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: const TextStyle(fontSize: 12)),
                        icon: const Icon(Icons.event_outlined, size: 16),
                        label: const Text('Make a Watch Plan')),
                  ]),
                ])),
          ]),
        ),
      ),
    );
  }
}
