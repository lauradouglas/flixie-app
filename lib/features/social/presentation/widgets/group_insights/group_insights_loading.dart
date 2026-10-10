import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class GroupInsightsLoading extends StatelessWidget {
  const GroupInsightsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        for (var i = 0; i < 3; i++) ...[
          const SkeletonBox(width: 180, height: 18, borderRadius: 6),
          const SizedBox(height: 10),
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Container(
                width: 268,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.tabBarBackgroundFocused,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.tabBarBorder),
                ),
                child: const Row(
                  children: [
                    SkeletonBox(width: 74, height: 124, borderRadius: 10),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: double.infinity, height: 16),
                          SizedBox(height: 7),
                          SkeletonBox(width: 96, height: 18, borderRadius: 10),
                          SizedBox(height: 7),
                          SkeletonBox(width: 130, height: 18, borderRadius: 10),
                          Spacer(),
                          SkeletonBox(width: 90, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
