import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import '../../models/milestone_badge.dart';
import 'film_milestone_badge.dart';
import 'profile_avatar_view.dart';

class BadgesExplainer extends StatelessWidget {
  const BadgesExplainer({super.key});

  void _explain(BuildContext context, String title, String text) =>
      showFlixiePromptSheet<void>(
          context: context,
          builder: (context) => FlixiePromptSheetContent(
                  title: Text(title),
                  content: Text(text),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it')),
                  ]));

  @override
  Widget build(BuildContext context) {
    final heading = TextStyle(
        color: context.colors.white, fontSize: 16, fontWeight: FontWeight.w800);
    final quiet =
        TextStyle(color: context.colors.light, fontSize: 12, height: 1.45);
    final paragraph = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: context.colors.light, height: 1.5);
    Widget panel(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: context.colors.white.withValues(alpha: .035),
            border:
                Border.all(color: context.colors.white.withValues(alpha: .055)),
            borderRadius: BorderRadius.circular(18)),
        child: child);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Badges & milestones',
          style: TextStyle(
              color: context.colors.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('Reach a milestone. Earn a badge for your profile.',
          style: TextStyle(
              color: context.colors.white, fontSize: 14, height: 1.4)),
      const SizedBox(height: 20),
      Text('A few examples', style: quiet),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
        final columns = constraints.maxWidth < 300 || largeText ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 16, children: [
          for (final badge in MilestoneBadge.examples)
            SizedBox(
                width: width,
                child: Column(children: [
                  FilmMilestoneBadge(badge: badge, size: 60),
                  const SizedBox(height: 8),
                  Text(badge.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(
                      badge.metal == 'purple'
                          ? 'Film god'
                          : '${badge.metal[0].toUpperCase()}${badge.metal.substring(1)}',
                      textAlign: TextAlign.center,
                      style: quiet),
                ])),
        ]);
      }),
      const SizedBox(height: 20),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('On your profile', style: heading),
              Text('Example', style: quiet),
            ]),
        const SizedBox(height: 12),
        Row(children: [
          const ProfileAvatarView(
              avatar: null,
              fallbackText: 'M',
              fallbackColor: FlixieColors.primary,
              size: 42,
              profileBadges: [],
              imageProvider: AssetImage('assets/icon/pip_emote_thumbs_up.png')),
          const SizedBox(width: 12),
          Flexible(child: Text('Maya', style: heading)),
          const SizedBox(width: 12),
          const FilmMilestoneBadge(
              badge: MilestoneBadge(
                  id: 'films_100',
                  target: 100,
                  metal: 'silver',
                  label: '100+ films'),
              size: 38),
        ]),
        const SizedBox(height: 10),
        Text('Choose up to 3 earned badges to show on your profile.',
            style: paragraph),
      ])),
      const SizedBox(height: 10),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('More ways to earn', style: heading),
        const SizedBox(height: 4),
        _MilestoneExampleRow(
            icon: Icons.emoji_events_outlined,
            label: 'Your first review',
            onTap: () => _explain(context, 'Your first review',
                'Write your first film or show review to reach this milestone. Find earned milestones in your profile.')),
        Divider(height: 1, color: context.colors.white.withValues(alpha: .08)),
        _MilestoneExampleRow(
            icon: Icons.people_outline,
            label: 'First watch together',
            onTap: () => _explain(context, 'First watch together',
                'Complete a watch plan where you and at least one other person both log the film. This earns your first watch-together milestone.')),
      ])),
      const SizedBox(height: 10),
      Text(
          'Different films count once. Rewatches have their own milestones.\nMilestone badges unlock as your diary grows.',
          style: paragraph),
      const SizedBox(height: 16),
      SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44)),
              child:
                  const Text('Keep browsing', style: TextStyle(fontSize: 14)))),
    ]);
  }
}

class _MilestoneExampleRow extends StatelessWidget {
  const _MilestoneExampleRow(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(icon, size: 23, color: context.colors.primaryText),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    size: 20, color: context.colors.light),
              ]))));
}
