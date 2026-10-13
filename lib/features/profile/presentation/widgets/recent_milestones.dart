import 'milestone_shield.dart';
export 'milestone_shield.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/profile_milestone.dart';

class RecentMilestones extends StatelessWidget {
  const RecentMilestones(
      {super.key,
      this.data,
      this.loading = false,
      this.failed = false,
      this.onRetry});
  final ProfileMilestones? data;
  final bool loading, failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final items = data?.earned.take(3).toList() ?? <ProfileMilestone>[];
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent milestones',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (items.isNotEmpty)
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21;
            return Wrap(spacing: 20, runSpacing: 16, children: [
              for (final item in items)
                SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 40) / 3
                        : constraints.maxWidth,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MilestoneShield(
                              group: item.group, family: item.family),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(item.title,
                                    style: TextStyle(
                                        color: context.colors.white,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                    item.earnedAt == null
                                        ? 'Earned'
                                        : 'Earned ${MaterialLocalizations.of(context).formatMediumDate(item.earnedAt!.toLocal())}',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        fontSize: 12)),
                              ])),
                        ])),
            ]);
          })
        else if (loading)
          Semantics(
              label: 'Loading milestones',
              child: const LinearProgressIndicator())
        else if (!failed && data != null)
          Text(
              'Your first milestone is still to come. Every movie moment counts.',
              style: TextStyle(color: context.colors.light)),
        if (failed) ...[
          const SizedBox(height: 8),
          Text('Couldn’t refresh milestones.',
              style: TextStyle(color: context.colors.light)),
          TextButton(onPressed: onRetry, child: const Text('Retry milestones')),
        ],
      ]),
    );
  }
}
