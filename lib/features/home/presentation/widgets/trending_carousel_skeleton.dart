import 'package:flutter/material.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

/// Matches the artwork-led Home carousel, including its adjacent-card peek.
class TrendingCarouselSkeleton extends StatelessWidget {
  const TrendingCarouselSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
        label: 'Loading films',
        child: ExcludeSemantics(
            child: Column(children: [
          SizedBox(
              height: 505 + 280 * (scale - 1).clamp(0.0, double.infinity),
              child: PageView.builder(
                controller: null,
                padEnds: false,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 1,
                itemBuilder: (_, __) => LayoutBuilder(
                    builder: (context, constraints) => Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: constraints.maxWidth * .08),
                              SizedBox(
                                  width: constraints.maxWidth * .84,
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SkeletonBox(
                                                height: 280, borderRadius: 18),
                                            const SizedBox(height: 14),
                                            const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 14),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      SkeletonBox(height: 22),
                                                      SizedBox(height: 8),
                                                      FractionallySizedBox(
                                                          widthFactor: .55,
                                                          child: SkeletonBox(
                                                              height: 12)),
                                                      SizedBox(height: 16),
                                                      SkeletonBox(height: 12),
                                                      SizedBox(height: 8),
                                                      SkeletonBox(height: 12),
                                                      SizedBox(height: 8),
                                                      FractionallySizedBox(
                                                          widthFactor: .75,
                                                          child: SkeletonBox(
                                                              height: 12)),
                                                      SizedBox(height: 20),
                                                      Row(children: [
                                                        SkeletonBox(
                                                            width: 44,
                                                            height: 44,
                                                            borderRadius: 22),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                            child: SkeletonBox(
                                                                height: 44,
                                                                borderRadius:
                                                                    22))
                                                      ]),
                                                    ])),
                                          ]))),
                              Expanded(
                                  child: SkeletonBox(
                                      height: 280, borderRadius: 18)),
                            ])),
              )),
          const SizedBox(height: 12),
          const SkeletonBox(width: 64, height: 6, borderRadius: 3),
          const SizedBox(height: 20),
        ])));
  }
}
