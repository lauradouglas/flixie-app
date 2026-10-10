import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/group_insights.dart';
import 'group_insights_style.dart';

class InsightMemberCard extends StatelessWidget {
  const InsightMemberCard({super.key, required this.member});
  final GroupInsightMember member;
  @override
  Widget build(BuildContext context) {
    final name = member.username.trim().isNotEmpty
        ? '@${member.username.trim()}'
        : member.name.trim().isNotEmpty
            ? member.name.trim()
            : '@user';
    final seed =
        member.username.trim().isNotEmpty ? member.username : member.name;
    final identity = Row(
      children: [
        if (member.rank > 0) ...[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: FlixieColors.primary.withValues(alpha: .35)),
            ),
            child: Text('${member.rank}',
                style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
        ],
        ProfileAvatarView(
          avatar: member.avatar,
          profileBadges: member.profileBadges,
          fallbackText:
              seed.trim().isEmpty ? '?' : seed.trim().characters.first,
          fallbackColor: FlixieColors.primary,
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: context.colors.light,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
    final activity = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${member.activityCount}',
            style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text('activities',
            style: TextStyle(color: context.colors.medium, fontSize: 11)),
        if ((member.badge ?? '').isNotEmpty)
          FlixiePill.label(label: Text(member.badge!)),
      ],
    );
    return InkWell(
      onTap: member.id.isEmpty
          ? null
          : () => context.push('/friends/${member.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: groupInsightsDecoration(context),
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            if (constraints.maxWidth < 330 || scale > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 8), activity],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                Flexible(child: activity),
              ],
            );
          },
        ),
      ),
    );
  }
}
