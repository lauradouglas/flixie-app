import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/watch_provider.dart';

class WatchRequestProviders extends StatelessWidget {
  const WatchRequestProviders({
    super.key,
    required this.providers,
    this.movieTitle,
    required this.myProviderIds,
    required this.friendProviderIds,
    required this.friendName,
    required this.loading,
    required this.loadingFriend,
    required this.showFriendMatch,
    required this.groupMode,
    required this.groupSelected,
    required this.groupProviderCounts,
    required this.groupProviderNameCounts,
    required this.groupMemberCount,
    required this.loadingGroup,
  });

  final List<WatchProvider> providers;
  final String? movieTitle;
  final Set<int> myProviderIds;
  final Set<int> friendProviderIds;
  final String? friendName;
  final bool loading;
  final bool loadingFriend;
  final bool showFriendMatch;
  final bool groupMode;
  final bool groupSelected;
  final Map<int, int> groupProviderCounts;
  final Map<String, int> groupProviderNameCounts;
  final int groupMemberCount;
  final bool loadingGroup;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ProviderPanel(
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 9),
            Expanded(
                child: Text(
              'Checking streaming availability…',
              style: TextStyle(color: context.colors.medium, fontSize: 12),
            )),
          ],
        ),
      );
    }
    if (providers.isEmpty) {
      return ProviderPanel(
        child: Row(
          children: [
            Icon(Icons.tv_off_outlined, size: 17, color: context.colors.medium),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not currently available on a streaming subscription.',
                style: TextStyle(color: context.colors.medium, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final shared = providers
        .where((provider) =>
            myProviderIds.contains(provider.id) &&
            friendProviderIds.contains(provider.id))
        .toList();
    return ProviderPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movieTitle == null
                ? 'WHERE TO WATCH'
                : 'WHERE TO WATCH · $movieTitle',
            style: TextStyle(
              color: context.colors.medium,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final provider in providers.take(8))
                ProviderMatchLogo(
                  provider: provider,
                  youHaveIt: myProviderIds.contains(provider.id),
                  friendHasIt: friendProviderIds.contains(provider.id),
                  compareFriend: showFriendMatch && !loadingFriend,
                  groupMatchCount: groupMode && groupSelected
                      ? _groupMatchCount(provider)
                      : 0,
                  groupMemberCount:
                      groupMode && groupSelected ? groupMemberCount : 0,
                ),
            ],
          ),
          const SizedBox(height: 9),
          if (groupMode && !groupSelected)
            Text(
              'Select a group to compare everyone’s streaming services.',
              style: TextStyle(color: context.colors.medium, fontSize: 12),
            )
          else if (groupMode && loadingGroup)
            Text(
              'Checking group members’ services…',
              style: TextStyle(color: context.colors.medium, fontSize: 12),
            )
          else if (groupMode)
            Text(
              _groupSummary,
              style: TextStyle(
                color: _hasGroupMatch
                    ? context.colors.success
                    : context.colors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (!showFriendMatch)
            Text(
              'Select a friend to compare your streaming services.',
              style: TextStyle(color: context.colors.medium, fontSize: 12),
            )
          else if (loadingFriend)
            Text(
              'Checking your friend’s services…',
              style: TextStyle(color: context.colors.medium, fontSize: 12),
            )
          else
            Text(
              shared.isNotEmpty
                  ? 'You and ${friendName ?? 'your friend'} can both stream it on ${shared.map((provider) => provider.providerName).join(', ')}.'
                  : 'No shared streaming service for you and ${friendName ?? 'your friend'}.',
              style: TextStyle(
                color: shared.isNotEmpty
                    ? context.colors.success
                    : context.colors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasGroupMatch => providers
      .any((provider) => _groupMatchCount(provider) == groupMemberCount);

  String get _groupSummary {
    if (groupMemberCount == 0) return 'No eligible group members found.';
    final everyone = providers
        .where(
          (provider) => _groupMatchCount(provider) == groupMemberCount,
        )
        .map((provider) => provider.providerName)
        .toList();
    if (everyone.isNotEmpty) {
      return 'Everyone can stream it on ${everyone.join(', ')}.';
    }
    final best = [...providers]..sort(
        (a, b) => _groupMatchCount(b).compareTo(_groupMatchCount(a)),
      );
    final provider = best.first;
    final count = _groupMatchCount(provider);
    return count == 0
        ? 'No group members have a matching streaming service.'
        : '$count of $groupMemberCount members have ${provider.providerName}.';
  }

  int _groupMatchCount(WatchProvider provider) =>
      groupProviderCounts[provider.id] ??
      groupProviderNameCounts[provider.matchKey] ??
      0;
}

class ProviderPanel extends StatelessWidget {
  const ProviderPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.tabBarBorder),
        ),
        child: child,
      );
}

class ProviderMatchLogo extends StatelessWidget {
  const ProviderMatchLogo({
    super.key,
    required this.provider,
    required this.youHaveIt,
    required this.friendHasIt,
    required this.compareFriend,
    this.groupMatchCount = 0,
    this.groupMemberCount = 0,
  });

  final WatchProvider provider;
  final bool youHaveIt;
  final bool friendHasIt;
  final bool compareFriend;
  final int groupMatchCount;
  final int groupMemberCount;

  @override
  Widget build(BuildContext context) {
    final friendShared = compareFriend && youHaveIt && friendHasIt;
    final groupShared =
        groupMemberCount > 0 && groupMatchCount == groupMemberCount;
    final highlighted = friendShared || groupShared;
    return Tooltip(
      message: groupShared
          ? 'Everyone in the group has ${provider.providerName}'
          : groupMemberCount > 0 && groupMatchCount > 0
              ? '$groupMatchCount of $groupMemberCount group members have ${provider.providerName}'
              : friendShared
                  ? 'You both have ${provider.providerName}'
                  : youHaveIt
                      ? 'You have ${provider.providerName}'
                      : provider.providerName,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highlighted
                    ? context.colors.success
                    : youHaveIt
                        ? FlixieColors.primary
                        : context.colors.tabBarBorder,
                width: highlighted ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CachedNetworkImage(
                imageUrl: provider.logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.live_tv_outlined,
                  color: context.colors.medium,
                ),
              ),
            ),
          ),
          if (highlighted)
            Positioned(
              right: -4,
              top: -4,
              child: Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: context.colors.success,
              ),
            ),
        ],
      ),
    );
  }
}
