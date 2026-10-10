import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

class GroupDetailTabs extends StatelessWidget implements PreferredSizeWidget {
  const GroupDetailTabs(
      {super.key, required this.controller, required this.pendingCount});
  final TabController controller;
  final int pendingCount;
  @override
  Size get preferredSize => const Size.fromHeight(62);
  @override
  Widget build(BuildContext context) => TabBar(
        controller: controller,
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        labelPadding: EdgeInsets.zero,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: FlixieColors.primary,
            width: 3,
          ),
          // Each tab owns a consistent, touch-friendly indicator
          // width. Label-sized indicators shrink Chat's underline
          // to a near-invisible dot after the insets are applied.
          insets: EdgeInsets.symmetric(horizontal: 18),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.white.withValues(alpha: 0.08),
        labelColor: FlixieColors.primary,
        unselectedLabelColor: context.colors.medium,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        tabs: [
          const Tab(text: 'Chat'),
          const Tab(text: 'Activity'),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Watch Plans'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    FlixiePill.label(label: Text('$pendingCount')),
                  ],
                ],
              ),
            ),
          ),
          const Tab(text: 'Insights'),
        ],
      );
}
