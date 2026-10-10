import 'package:flutter/material.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'cast_card.dart';

/// Mirrors the watch-entry row's icon, evidence and action while history loads.
class MovieWatchEntrySkeleton extends StatelessWidget {
  const MovieWatchEntrySkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading watch history',
        child: ExcludeSemantics(
            child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 326 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.2;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const SkeletonBox(width: 48, height: 48, borderRadius: 24),
                const SizedBox(width: 10),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      FractionallySizedBox(
                          widthFactor: .75, child: SkeletonBox(height: 14)),
                      SizedBox(height: 8),
                      FractionallySizedBox(
                          widthFactor: .55, child: SkeletonBox(height: 11)),
                    ])),
                if (!stacked) ...[
                  const SizedBox(width: 8),
                  const SkeletonBox(width: 90, height: 40, borderRadius: 20),
                ],
              ]),
              if (stacked) ...[
                const SizedBox(height: 14),
                const Align(
                    alignment: Alignment.centerRight,
                    child:
                        SkeletonBox(width: 90, height: 40, borderRadius: 20)),
              ],
            ]);
          }),
        )),
      );
}

class MovieProvidersSkeleton extends StatelessWidget {
  const MovieProvidersSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading watch providers',
        child: ExcludeSemantics(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FlixieSectionHeader(title: 'Where to watch'),
          const SizedBox(height: 12),
          const Row(children: [
            Expanded(child: SkeletonBox(height: 40)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 40)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 40)),
          ]),
          for (var i = 0; i < 2; i++)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  SkeletonBox(width: 40, height: 40),
                  SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        FractionallySizedBox(
                            widthFactor: .6, child: SkeletonBox(height: 14)),
                        SizedBox(height: 8),
                        FractionallySizedBox(
                            widthFactor: .8, child: SkeletonBox(height: 12)),
                      ])),
                  SizedBox(width: 16),
                  SkeletonBox(width: 20, height: 20),
                ])),
        ])),
      );
}

class MovieCastSkeleton extends StatelessWidget {
  const MovieCastSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading cast and crew',
        child: ExcludeSemantics(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FlixieSectionHeader(title: 'Top Cast'),
          const SizedBox(height: 8),
          SizedBox(
              height: CastCard.heightFor(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, __) => SizedBox(
                    width: CastCard.widthFor(context),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(
                              height: CastCard.widthFor(context) * 1.5,
                              borderRadius: 18),
                          const SizedBox(height: 10),
                          const SkeletonBox(height: 14),
                          const SizedBox(height: 8),
                          const FractionallySizedBox(
                              widthFactor: .65, child: SkeletonBox(height: 12)),
                        ])),
              )),
        ])),
      );
}
