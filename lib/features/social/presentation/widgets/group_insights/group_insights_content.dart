import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import '../../controllers/group_insights_controller.dart';
import 'group_insight_highlight.dart';
import 'group_insight_member.dart';
import 'group_insight_review.dart';
import 'group_insights_period.dart';
import 'group_insights_pulse.dart';

class GroupInsightsContent extends StatelessWidget {
  const GroupInsightsContent({super.key, required this.controller});
  final GroupInsightsController controller;
  @override
  Widget build(BuildContext context) {
    final insights = controller.insights;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      color: FlixieColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          GroupInsightsPeriod(
            allTime: controller.allTime,
            onChanged: controller.setAllTime,
          ),
          const SizedBox(height: 12),
          if (controller.error != null)
            _InsightsMessage(
              error: controller.error,
              onRetry: controller.refresh,
            )
          else if (insights.isCompletelyEmpty)
            const _InsightsMessage()
          else ...[
            InsightsPulseStrip(insights: insights),
            const SizedBox(height: 18),
            if (insights.mostWatchedThisMonth.isNotEmpty) ...[
              const FlixieSectionHeader(title: 'Highlights'),
              const SizedBox(height: 10),
              InsightHighlightCard(movie: insights.mostWatchedThisMonth.first),
              const SizedBox(height: 22),
            ],
            if (insights.recentReviews.isNotEmpty) ...[
              const FlixieSectionHeader(title: 'Recent Reviews'),
              const SizedBox(height: 10),
              for (final review in insights.recentReviews)
                Padding(
                  key: ValueKey('insight-review-${review.id}'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InsightReviewCard(review: review),
                ),
              const SizedBox(height: 8),
            ],
            if (insights.mostActiveMembers.isNotEmpty) ...[
              const FlixieSectionHeader(title: 'Top contributors'),
              const SizedBox(height: 10),
              for (final member in insights.mostActiveMembers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InsightMemberCard(member: member),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InsightsMessage extends StatelessWidget {
  const _InsightsMessage({this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              error == null
                  ? Icons.auto_graph_outlined
                  : Icons.insights_outlined,
              size: 48,
              color: context.colors.medium,
            ),
            const SizedBox(height: 16),
            Text(
              error ?? 'No group insights yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.light,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (error == null)
              Text(
                'Start watching, rating, reviewing, or discussing movies with this group.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.medium, height: 1.4),
              )
            else
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
