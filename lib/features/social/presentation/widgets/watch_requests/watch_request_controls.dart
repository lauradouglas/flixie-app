import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_segmented_control.dart';

enum WatchRequestAudience { friends, groups }

class WatchRequestAudienceSwitcher extends StatelessWidget {
  const WatchRequestAudienceSwitcher({
    super.key,
    required this.selected,
    required this.friendActiveCount,
    required this.groupActiveCount,
    required this.onChanged,
  });

  final WatchRequestAudience selected;
  final int friendActiveCount;
  final int groupActiveCount;
  final ValueChanged<WatchRequestAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    return FlixieSegmentedControl<WatchRequestAudience>(
      value: selected,
      onChanged: onChanged,
      segments: [
        FlixieSegment(
          value: WatchRequestAudience.friends,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.group_outlined),
            const SizedBox(width: 8),
            Flexible(child: Text('Friends · $friendActiveCount')),
          ]),
        ),
        FlixieSegment(
          value: WatchRequestAudience.groups,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.groups_2_outlined),
            const SizedBox(width: 8),
            Flexible(child: Text('Groups · $groupActiveCount')),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class WatchRequestSectionHeader extends StatelessWidget {
  const WatchRequestSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.colors.light,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        FlixiePill.label(label: Text('$count')),
      ],
    );
  }
}
