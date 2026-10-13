import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/models/watch_request.dart';

/// Shows the existing account-scoped plan snapshot beside the activity feed.
/// It starts no extra requests and sends all plan actions to their owning page.
class SocialTabletCompanion extends StatelessWidget {
  const SocialTabletCompanion({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final viewer = auth.dbUser?.id;
    if (viewer == null) return const SizedBox.shrink();
    final cache = context.watch<WatchRequestCache?>();
    final plans = (cache?.hasDirectSnapshot == true
            ? cache!.direct
            : auth.cachedWatchRequests ?? const <WatchRequest>[])
        .where((plan) =>
            plan.requesterId == viewer ||
            plan.recipientId == viewer ||
            plan.participantFor(viewer) != null)
        .where((plan) => !{
              WatchPlanStage.past,
              WatchPlanStage.cancelled,
              WatchPlanStage.expired
            }.contains(plan.planStageFor(viewer)))
        .take(3)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 0, 24),
      children: [
        const FlixieSectionHeader(title: 'Watch together'),
        const SizedBox(height: 16),
        if (plans.isEmpty)
          Text('Make a plan and find something to watch with your people.',
              style: TextStyle(
                  color: context.colors.light, fontSize: 15, height: 1.5)),
        for (final plan in plans) ...[
          Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/watch-requests/${plan.id}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.watchPlanTitle,
                          style: TextStyle(
                              color: context.colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      if (plan.otherUser(viewer)
                          case final WatchRequestUser other)
                        Row(children: [
                          SizedBox.square(
                              dimension: 44,
                              child: Center(
                                  child: ProfileAvatarView(
                                      avatar: other.avatar,
                                      fallbackColor:
                                          context.colors.surfaceElevated,
                                      profileBadges: other.profileBadges,
                                      size: 32,
                                      fallbackText: other.displayName.isEmpty
                                          ? '?'
                                          : other
                                              .displayName.characters.first))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('With ${other.displayName}',
                                  style:
                                      TextStyle(color: context.colors.light))),
                        ]),
                      const SizedBox(height: 8),
                      Text(plan.planStageFor(viewer).label,
                          style: TextStyle(color: context.colors.primaryText)),
                      const SizedBox(height: 12),
                      Text(plan.planStageFor(viewer).primaryActionLabel,
                          style: TextStyle(
                              color: context.colors.primaryText,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () => context.go('/plans'),
            icon: const Icon(Icons.event_outlined),
            label: const Text('All Watch Plans')),
        const SizedBox(height: 32),
        const FlixieSectionHeader(title: 'Your people'),
        const SizedBox(height: 8),
        TextButton.icon(
            onPressed: () => context.go('/social?tab=people'),
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('Find friends')),
        TextButton.icon(
            onPressed: () => context.push('/invite-friend?from=social'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Invite friends')),
      ],
    );
  }
}
