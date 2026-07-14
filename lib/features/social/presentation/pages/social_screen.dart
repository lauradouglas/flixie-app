import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/add_friend_sheet.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_avatar.dart';
import 'package:flixie_app/features/social/presentation/widgets/invitation_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/pending_friend_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/social_section_header.dart';
import 'package:flixie_app/features/social/presentation/widgets/segmented_toggle.dart';
import 'package:flixie_app/features/social/presentation/widgets/visibility_chip.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _selectedTab = 0; // 0 = Friends, 1 = Groups

  void _showAddFriendSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddFriendSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        title: const Text(
          'Social',
          style: TextStyle(
            color: FlixieColors.light,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (_selectedTab == 0) {
                _showAddFriendSheet();
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Use Create on the Groups tab for groups.')),
              );
            },
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: _selectedTab == 0 ? 'Find friends' : 'Create group',
          ),
        ],
      ),
      body: Column(
        children: [
          SocialSegmentedToggle(
            selectedIndex: _selectedTab,
            labels: const ['Friends', 'Groups'],
            onChanged: (i) => setState(() => _selectedTab = i),
          ),
          Expanded(
            child: _selectedTab == 0
                ? const _FriendsSubView()
                : const _GroupsSubView(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friends sub-view
// ---------------------------------------------------------------------------

class _FriendsSubView extends StatefulWidget {
  const _FriendsSubView();

  @override
  State<_FriendsSubView> createState() => _FriendsSubViewState();
}

class _FriendsSubViewState extends State<_FriendsSubView> {
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  FriendsData? _friendsData;
  List<ActivityListItem> _activity = [];
  List<Group> _groupsPreview = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _friendActions.getFriends(userId),
        _friendActions.getFriendsActivityLists(userId),
        GroupService.getUserGroups(userId).catchError((_) => <Group>[]),
      ]);
      if (mounted) {
        setState(() {
          _friendsData = results[0] as FriendsData;
          _activity = results[1] as List<ActivityListItem>;
          _groupsPreview = results[2] as List<Group>;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      logger.e('FriendsSubView load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load friends.';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddFriendSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddFriendSheet(),
    );
  }

  Future<void> _acceptRequest(Friendship friendship) async {
    try {
      await _friendActions.acceptRequest(friendship.id);
      if (mounted) {
        final updated = _friendsData!.copyWith(
          pendingFriends: _friendsData!.pendingFriends
              .where((f) => f.id != friendship.id)
              .toList(),
          friendships: [
            ..._friendsData!.friendships,
            Friendship(
              id: friendship.id,
              friend: friendship.friendUser,
              createdAt: '',
              updatedAt: '',
            ),
          ],
        );
        setState(() => _friendsData = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Now friends with ${friendship.friendUser?.username ?? 'user'}')),
        );
        // Repoll friends activity now that we have a new friend.
        final userId = context.read<AuthProvider>().dbUser?.id;
        if (userId != null) {
          _friendActions.getFriendsActivityLists(userId).then((activity) {
            if (mounted) setState(() => _activity = activity);
          }).catchError((_) {});
        }
      }
    } catch (e) {
      logger.e('Accept request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept friend request')),
        );
      }
    }
  }

  Future<void> _declineRequest(Friendship friendship) async {
    try {
      await _friendActions.declineRequest(friendship.id);
      if (mounted) {
        setState(() {
          _friendsData = _friendsData!.copyWith(
            pendingFriends: _friendsData!.pendingFriends
                .where((f) => f.id != friendship.id)
                .toList(),
          );
        });
      }
    } catch (e) {
      logger.e('Decline request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decline friend request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child:
            Text(_error!, style: const TextStyle(color: FlixieColors.medium)),
      );
    }

    final data = _friendsData;
    final friends = data?.friendships
            .map((f) => f.friendUser)
            .whereType<FriendshipUser>()
            .toList() ??
        const <FriendshipUser>[];
    final query = _searchController.text.trim().toLowerCase();
    final filteredFriends = query.isEmpty
        ? friends
        : friends
            .where((friend) =>
                friend.username.toLowerCase().contains(query) ||
                (friend.firstName ?? '').toLowerCase().contains(query))
            .toList();
    final authUser = context.read<AuthProvider>().dbUser;
    final myWatchlistIds =
        authUser?.movieWatchlist?.map((item) => item.movieId).toSet() ??
            <int>{};

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (friends.isNotEmpty) ...[
              _FriendStoryStrip(
                friends: friends,
                onAddTap: _showAddFriendSheet,
              ),
              const SizedBox(height: 14),
            ],
            _SocialQuickStats(
              friendCount: friends.length,
              pendingCount: data?.pendingFriends.length ?? 0,
              groupCount: _groupsPreview.length,
              activityCount: _activity.length,
            ),
            const SizedBox(height: 14),
            _FriendSearchField(controller: _searchController),
            const SizedBox(height: 14),
            // Pending requests section
            if (data != null &&
                (data.pendingFriends.isNotEmpty ||
                    data.requestedFriends.isNotEmpty)) ...[
              _PendingSocialSummary(
                incomingCount: data.pendingFriends.length,
                outgoingCount: data.requestedFriends.length,
                onAddFriend: _showAddFriendSheet,
              ),
              const SizedBox(height: 8),
              ...data.pendingFriends.map(
                (f) => PendingFriendCard(
                  friendship: f,
                  onAccept: () => _acceptRequest(f),
                  onDecline: () => _declineRequest(f),
                  onTap: () {
                    final userId = f.friendUser?.id;
                    if (userId != null) context.push('/friends/$userId');
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Friends section
            if (data != null) ...[
              _EnhancedFriendsSection(
                friends: filteredFriends,
                totalCount: friends.length,
                activity: _activity,
                myWatchlistIds: myWatchlistIds,
                searchQuery: query,
                onAddFriend: _showAddFriendSheet,
                onRequestWatch: _showRequestWatchHint,
              ),
              const SizedBox(height: 16),
            ],

            // Activity section
            const SocialSectionHeader(title: 'FRIEND ACTIVITY'),
            const SizedBox(height: 8),
            if (_activity.isEmpty)
              _ActivityEmptyState(
                hasFriends: friends.isNotEmpty,
                onAddFriend: _showAddFriendSheet,
                onOpenWatchlist: () => context.push('/watchlist'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activity.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ActivityTile(item: _activity[i]),
              ),
            if (_groupsPreview.isNotEmpty) ...[
              const SizedBox(height: 20),
              _GroupsPreviewSection(groups: _groupsPreview.take(3).toList()),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showRequestWatchHint(FriendshipUser friend) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Open a movie and tap Request to watch with ${friend.shortName}.',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friends widgets
// ---------------------------------------------------------------------------

class _FriendStoryStrip extends StatelessWidget {
  const _FriendStoryStrip({required this.friends, required this.onAddTap});

  final List<FriendshipUser> friends;
  final VoidCallback onAddTap;

  Color _avatarColor(Map<String, dynamic>? iconColor) {
    final raw = (iconColor?['hexCode'] ?? iconColor?['hex']) as String?;
    if (raw == null || raw.isEmpty) return FlixieColors.primary;
    final hex = raw.replaceAll('#', '');
    return Color(int.tryParse('0xFF$hex') ?? FlixieColors.primary.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          if (index == friends.length) {
            return GestureDetector(
              onTap: onAddTap,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    child: Icon(Icons.add, color: FlixieColors.light),
                  ),
                  SizedBox(height: 4),
                  SizedBox(
                    width: 48,
                    height: 12,
                  ),
                ],
              ),
            );
          }
          final friend = friends[index];
          final initial = friend.username.isNotEmpty
              ? friend.username[0].toUpperCase()
              : '?';
          return GestureDetector(
            onTap: () => context.push('/friends/${friend.id}'),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: _avatarColor(friend.iconColor),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 48,
                  child: Text(
                    friend.firstName?.isNotEmpty == true
                        ? friend.firstName!
                        : friend.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SocialQuickStats extends StatelessWidget {
  const _SocialQuickStats({
    required this.friendCount,
    required this.pendingCount,
    required this.groupCount,
    required this.activityCount,
  });

  final int friendCount;
  final int pendingCount;
  final int groupCount;
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat(Icons.people_alt_outlined, '$friendCount', 'Friends',
            FlixieColors.primary),
        const SizedBox(width: 8),
        _stat(Icons.notifications_active_outlined, '$pendingCount', 'Pending',
            FlixieColors.warning),
        const SizedBox(width: 8),
        _stat(Icons.groups_2_outlined, '$groupCount', 'Groups',
            FlixieColors.secondary),
        const SizedBox(width: 8),
        _stat(Icons.bolt_rounded, '$activityCount', 'Updates',
            FlixieColors.tertiary),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendSearchField extends StatelessWidget {
  const _FriendSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: FlixieColors.light, fontSize: 14),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search friends',
        hintStyle: const TextStyle(color: FlixieColors.medium),
        prefixIcon:
            const Icon(Icons.search_rounded, color: FlixieColors.medium),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon:
                    const Icon(Icons.close_rounded, color: FlixieColors.medium),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: FlixieColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlixieColors.primary),
        ),
      ),
    );
  }
}

class _PendingSocialSummary extends StatelessWidget {
  const _PendingSocialSummary({
    required this.incomingCount,
    required this.outgoingCount,
    required this.onAddFriend,
  });

  final int incomingCount;
  final int outgoingCount;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: FlixieColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (incomingCount > 0)
                  '$incomingCount friend request${incomingCount == 1 ? '' : 's'}',
                if (outgoingCount > 0)
                  '$outgoingCount sent invite${outgoingCount == 1 ? '' : 's'}',
              ].join(' · '),
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onAddFriend,
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.primary,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _EnhancedFriendsSection extends StatelessWidget {
  const _EnhancedFriendsSection({
    required this.friends,
    required this.totalCount,
    required this.activity,
    required this.myWatchlistIds,
    required this.searchQuery,
    required this.onAddFriend,
    required this.onRequestWatch,
  });

  final List<FriendshipUser> friends;
  final int totalCount;
  final List<ActivityListItem> activity;
  final Set<int> myWatchlistIds;
  final String searchQuery;
  final VoidCallback onAddFriend;
  final ValueChanged<FriendshipUser> onRequestWatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SocialSectionHeader(title: 'FRIENDS')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: FlixieColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$totalCount',
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onAddFriend,
              style: TextButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (friends.isEmpty)
          _NoFriendsCard(
            isSearching: searchQuery.isNotEmpty,
            onAddFriend: onAddFriend,
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final friend = friends[index];
                final insights = _FriendInsights.fromActivity(
                  friend: friend,
                  activity: activity,
                  myWatchlistIds: myWatchlistIds,
                );
                return _EnhancedFriendCard(
                  friend: friend,
                  insights: insights,
                  onRequestWatch: () => onRequestWatch(friend),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _NoFriendsCard extends StatelessWidget {
  const _NoFriendsCard({required this.isSearching, required this.onAddFriend});

  final bool isSearching;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.person_add_outlined,
            color: FlixieColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSearching
                  ? 'No friends match your search.'
                  : 'Add friends to compare watchlists and see activity.',
              style: const TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
          ),
          if (!isSearching)
            TextButton(
              onPressed: onAddFriend,
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }
}

class _FriendInsights {
  const _FriendInsights({
    required this.sharedWatchlistCount,
    required this.highRatingCount,
    this.latestActivity,
  });

  final int sharedWatchlistCount;
  final int highRatingCount;
  final ActivityListItem? latestActivity;

  String get primaryLabel {
    if (sharedWatchlistCount > 0) {
      return '$sharedWatchlistCount shared watchlist';
    }
    if (highRatingCount > 0) return '$highRatingCount strong ratings';
    return 'Tap for profile';
  }

  String get secondaryLabel {
    final item = latestActivity;
    if (item == null) return 'No activity yet';
    final title = item.mediaTitle ?? 'a title';
    switch (item.type) {
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return 'Added $title';
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return 'Watched $title';
      case ActivityListType.movieRating:
      case ActivityListType.showRating:
        return 'Rated $title';
      case ActivityListType.movieReview:
      case ActivityListType.showReview:
        return 'Reviewed $title';
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        return 'Favourited $title';
      case ActivityListType.watchRequest:
      case ActivityListType.watchRequestAccepted:
      case ActivityListType.watchRequestSent:
        return 'Shared $title';
      case ActivityListType.unknown:
        return 'Recent activity';
    }
  }

  static _FriendInsights fromActivity({
    required FriendshipUser friend,
    required List<ActivityListItem> activity,
    required Set<int> myWatchlistIds,
  }) {
    final friendActivity = activity
        .where((item) => item.userId == friend.id)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final sharedWatchlist = friendActivity.where((item) {
      return item.type == ActivityListType.movieWatchlist &&
          item.movieId != null &&
          myWatchlistIds.contains(item.movieId);
    }).length;
    final highRatings = friendActivity.where((item) {
      return item.type == ActivityListType.movieRating &&
          (item.mediaRating ?? 0) >= 8;
    }).length;
    return _FriendInsights(
      sharedWatchlistCount: sharedWatchlist,
      highRatingCount: highRatings,
      latestActivity: friendActivity.isEmpty ? null : friendActivity.first,
    );
  }
}

class _EnhancedFriendCard extends StatelessWidget {
  const _EnhancedFriendCard({
    required this.friend,
    required this.insights,
    required this.onRequestWatch,
  });

  final FriendshipUser friend;
  final _FriendInsights insights;
  final VoidCallback onRequestWatch;

  Color get _avatarColor {
    final raw =
        (friend.iconColor?['hexCode'] ?? friend.iconColor?['hex']) as String?;
    if (raw == null || raw.isEmpty) return FlixieColors.primary;
    final hex = raw.replaceAll('#', '');
    return Color(int.tryParse('0xFF$hex') ?? FlixieColors.primary.toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    final initial = friend.initials ??
        (friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?');
    return GestureDetector(
      onTap: () => context.push('/friends/${friend.id}'),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _avatarColor.withValues(alpha: 0.25),
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: _avatarColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Friend actions',
                  padding: EdgeInsets.zero,
                  color: FlixieColors.surfaceElevated,
                  onSelected: (value) {
                    if (value == 'profile') {
                      context.push('/friends/${friend.id}');
                    } else if (value == 'request') {
                      onRequestWatch();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(children: [
                        Icon(Icons.person_outline,
                            color: FlixieColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('View profile',
                            style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'request',
                      child: Row(children: [
                        Icon(Icons.movie_filter_outlined,
                            color: FlixieColors.secondary, size: 18),
                        SizedBox(width: 8),
                        Text('Request watch',
                            style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                  ],
                  child: const Icon(Icons.more_horiz_rounded,
                      color: FlixieColors.medium, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              friend.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              insights.primaryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              insights.secondaryLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState({
    required this.hasFriends,
    required this.onAddFriend,
    required this.onOpenWatchlist,
  });

  final bool hasFriends;
  final VoidCallback onAddFriend;
  final VoidCallback onOpenWatchlist;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No recent activity yet.',
            style: TextStyle(
              color: FlixieColors.light,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFriends
                ? 'Request a watch or add more titles to spark activity.'
                : 'Add friends to start seeing ratings, watchlists and reviews here.',
            style: const TextStyle(color: FlixieColors.medium, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: hasFriends ? onOpenWatchlist : onAddFriend,
                icon: Icon(hasFriends
                    ? Icons.movie_filter_outlined
                    : Icons.person_add_outlined),
                label: Text(hasFriends ? 'Pick a movie' : 'Add friends'),
                style: FilledButton.styleFrom(
                  foregroundColor: FlixieColors.light,
                  backgroundColor: FlixieColors.primary.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupsPreviewSection extends StatelessWidget {
  const _GroupsPreviewSection({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SocialSectionHeader(title: 'YOUR GROUPS')),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Switch to Groups to view all.')),
                );
              },
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...groups.map((group) => GroupCard(group: group)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Groups sub-view
// ---------------------------------------------------------------------------

class _GroupsSubView extends StatefulWidget {
  const _GroupsSubView();

  @override
  State<_GroupsSubView> createState() => _GroupsSubViewState();
}

class _GroupsSubViewState extends State<_GroupsSubView> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  List<Group> _groups = [];
  final Map<String, GroupMember> _pendingInvites = {};
  final Map<String, int> _memberCounts = {};
  final Map<String, FlixieNotification> _inviteNotifications = {};
  int _innerTab = 0; // 0 = Groups, 1 = Invites
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // Fetch groups and notifications in parallel
      final topResults = await Future.wait<Object>([
        GroupService.getUserGroups(userId),
        NotificationService.getNotifications(userId)
            .catchError((_) => <FlixieNotification>[]),
      ]);
      final groups = topResults[0] as List<Group>;
      final allNotifications = topResults[1] as List<FlixieNotification>;

      // Build map of groupId -> pending GROUP_INVITE notification.
      final inviteNotifs = <String, FlixieNotification>{};
      final notifOnlyGroups = <Group>[];
      for (final notif in allNotifications) {
        if (notif.type == FlixieNotification.groupInvite &&
            notif.action != FlixieNotification.actionAccepted &&
            notif.action != FlixieNotification.actionDeclined) {
          final groupId = notif.groupInviteGroupId;
          if (groupId == null) continue;
          inviteNotifs[groupId] = notif;
          if (!groups.any((g) => g.id == groupId)) {
            final name = notif.groupInviteGroupName ?? 'Invited Group';
            notifOnlyGroups.add(Group(id: groupId, name: name, ownerId: ''));
          }
        }
      }

      // Combine confirmed groups with notification-only invited groups.
      final allGroups = [...groups, ...notifOnlyGroups];

      final pendingInvites = <String, GroupMember>{
        for (final g in notifOnlyGroups)
          g.id!: GroupMember(
            groupId: g.id!,
            memberId: userId,
            role: 'MEMBER',
            inviteStatus: 'PENDING',
          ),
      };
      final memberCounts = <String, int>{};
      final groupsWithId = groups.where((g) => g.id != null).toList();
      final memberResults = await Future.wait(
        groupsWithId.map(
          (g) => GroupService.getGroupMembers(g.id!)
              .catchError((_) => <GroupMember>[]),
        ),
      );
      for (var i = 0; i < groupsWithId.length; i++) {
        final group = groupsWithId[i];
        final members = memberResults[i];
        memberCounts[group.id!] = members.where((m) => m.isAccepted).length;
        final myMembership = members.firstWhere(
          (m) => m.memberId == userId,
          orElse: () => GroupMember(
            groupId: group.id!,
            memberId: userId,
            role: 'MEMBER',
            inviteStatus: null,
          ),
        );
        if (myMembership.isPending) {
          pendingInvites[group.id!] = myMembership;
        }
      }

      if (mounted) {
        setState(() {
          _groups = allGroups;
          _pendingInvites
            ..clear()
            ..addAll(pendingInvites);
          _memberCounts
            ..clear()
            ..addAll(memberCounts);
          _inviteNotifications
            ..clear()
            ..addAll(inviteNotifs);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      logger.e('GroupsSubView load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load groups.';
        });
      }
    }
  }

  Future<void> _respondToInvite(Group group, String status) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || group.id == null) return;
    try {
      await GroupService.updateMemberInviteStatus(group.id!, userId, status);

      // Keep Firestore members in sync immediately after accepting an invite.
      if (status == 'ACCEPTED') {
        try {
          final members = await GroupService.getGroupMembers(group.id!);
          final memberIds = members
              .where((m) => m.isAccepted)
              .map((m) => m.memberId)
              .toSet()
              .toList();
          if (!memberIds.contains(userId)) memberIds.add(userId);
          await ChatService.getOrCreateGroupConversation(
            creatorId: userId,
            pgGroupId: group.id!,
            name: group.name,
            memberIds: memberIds,
          );
        } catch (e) {
          logger.w('Invite accepted but Firestore sync failed: $e');
        }
      }

      // Also update the associated GROUP_INVITE notification so it reflects
      // the accept/decline on the notifications screen.
      final notif = _inviteNotifications[group.id];
      if (notif?.id != null) {
        final action = status == 'ACCEPTED'
            ? FlixieNotification.actionAccepted
            : FlixieNotification.actionDeclined;
        NotificationService.updateNotification(
          notif!.id!,
          action: action,
          read: true,
        ).catchError((e) {
          logger.w('Failed to update GROUP_INVITE notification: $e');
          return const FlixieNotification(userId: '', type: '', message: '');
        });
      }
      if (mounted) {
        setState(() {
          _pendingInvites.remove(group.id);
          _inviteNotifications.remove(group.id);
          if (status == 'DECLINED') {
            _groups.removeWhere((g) => g.id == group.id);
          }
        });
      }
    } catch (e) {
      logger.e('Respond to invite error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update invitation')),
        );
      }
    }
  }

  void _showCreateGroupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateGroupSheet(
        onCreated: (group) {
          if (mounted) setState(() => _groups.add(group));
        },
      ),
    );
  }

  int get _totalMembers =>
      _memberCounts.values.fold<int>(0, (sum, count) => sum + count);

  int get _activeGroups => _groups.where((group) {
        final updated = DateTime.tryParse(group.updatedAt ?? '');
        if (updated == null) return false;
        return DateTime.now().difference(updated).inDays <= 14;
      }).length;

  List<Group> _sortGroups(List<Group> groups) {
    return [...groups]..sort((a, b) {
        final aUpdated = DateTime.tryParse(a.updatedAt ?? '');
        final bUpdated = DateTime.tryParse(b.updatedAt ?? '');
        if (aUpdated != null && bUpdated != null) {
          final byRecent = bUpdated.compareTo(aUpdated);
          if (byRecent != 0) return byRecent;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  List<Group> _filterGroups(List<Group> groups) {
    final query = _searchController.text.trim().toLowerCase();
    final sorted = _sortGroups(groups);
    if (query.isEmpty) return sorted;
    return sorted.where((group) {
      return group.name.toLowerCase().contains(query) ||
          (group.abbreviation ?? '').toLowerCase().contains(query) ||
          (group.description ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child:
            Text(_error!, style: const TextStyle(color: FlixieColors.medium)),
      );
    }

    final pendingGroups =
        _groups.where((g) => _pendingInvites.containsKey(g.id)).toList();
    final myGroups =
        _groups.where((g) => !_pendingInvites.containsKey(g.id)).toList();

    return Column(
      children: [
        _GroupsTabBar(
          selectedIndex: _innerTab,
          pendingCount: pendingGroups.length,
          onChanged: (i) => setState(() => _innerTab = i),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: FlixieColors.primary,
            child: _innerTab == 1
                ? _buildRequestsTab(pendingGroups)
                : _buildMyGroupsTab(pendingGroups, myGroups),
          ),
        ),
      ],
    );
  }

  Widget _buildMyGroupsTab(List<Group> pendingGroups, List<Group> myGroups) {
    final sortedGroups = _sortGroups(myGroups);
    final displayedGroups = _filterGroups(myGroups);
    final recentGroups = sortedGroups.take(8).toList();
    final isSearching = _searchController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupStatsRow(
            groupCount: myGroups.length,
            inviteCount: pendingGroups.length,
            memberCount: _totalMembers,
            activeCount: _activeGroups,
          ),
          const SizedBox(height: 14),
          _GroupSearchField(controller: _searchController),
          const SizedBox(height: 14),
          if (recentGroups.isNotEmpty) ...[
            const SocialSectionHeader(title: 'RECENT GROUPS'),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentGroups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final g = recentGroups[i];
                  return GestureDetector(
                    onTap: () => context.push('/groups/${g.id}'),
                    child: Column(
                      children: [
                        GroupAvatar(group: g, radius: 20),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 56,
                          child: Text(
                            g.abbreviation?.isNotEmpty == true
                                ? g.abbreviation!
                                : g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (pendingGroups.isNotEmpty) ...[
            SocialSectionHeader(
              title: 'PENDING INVITATIONS',
              rightLabel: '${pendingGroups.length} REQUESTS',
            ),
            const SizedBox(height: 10),
            ...pendingGroups.map((g) => GroupInvitationCard(
                  group: g,
                  invitedByUsername: _inviteNotifications[g.id]?.senderName,
                  onAccept: () => _respondToInvite(g, 'ACCEPTED'),
                  onDecline: () => _respondToInvite(g, 'DECLINED'),
                )),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              const Expanded(
                child: SocialSectionHeader(title: 'MY COMMUNITIES'),
              ),
              FilledButton.tonalIcon(
                onPressed: _showCreateGroupSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create'),
                style: FilledButton.styleFrom(
                  foregroundColor: FlixieColors.light,
                  backgroundColor: FlixieColors.primary.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (displayedGroups.isEmpty)
            _NoGroupsCard(
              isSearching: isSearching,
              onCreateGroup: _showCreateGroupSheet,
            )
          else
            ...displayedGroups.map((g) => GroupCard(
                  group: g,
                  memberCount: _memberCounts[g.id],
                  statusLabel: _pendingInvites.containsKey(g.id)
                      ? 'Invite pending'
                      : _groupFreshnessLabel(g),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(List<Group> pendingGroups) {
    if (pendingGroups.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _NoGroupInvitesCard(onCreateGroup: _showCreateGroupSheet),
      );
    }
    final sortedPending = _sortGroups(pendingGroups);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PendingGroupInviteSummary(count: sortedPending.length),
          const SizedBox(height: 12),
          ...sortedPending.map((g) => GroupInvitationCard(
                group: g,
                invitedByUsername: _inviteNotifications[g.id]?.senderName,
                onAccept: () => _respondToInvite(g, 'ACCEPTED'),
                onDecline: () => _respondToInvite(g, 'DECLINED'),
              )),
        ],
      ),
    );
  }

  String _groupFreshnessLabel(Group group) {
    final updated = DateTime.tryParse(group.updatedAt ?? '');
    if (updated == null) return 'Community';
    final diff = DateTime.now().difference(updated);
    if (diff.inHours < 24) return 'Active today';
    if (diff.inDays < 7) return 'Active this week';
    return 'Community';
  }
}

class _GroupStatsRow extends StatelessWidget {
  const _GroupStatsRow({
    required this.groupCount,
    required this.inviteCount,
    required this.memberCount,
    required this.activeCount,
  });

  final int groupCount;
  final int inviteCount;
  final int memberCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat(Icons.groups_2_outlined, '$groupCount', 'Groups',
            FlixieColors.primary),
        const SizedBox(width: 8),
        _stat(Icons.mail_outline_rounded, '$inviteCount', 'Invites',
            FlixieColors.warning),
        const SizedBox(width: 8),
        _stat(Icons.people_outline_rounded, '$memberCount', 'Members',
            FlixieColors.secondary),
        const SizedBox(width: 8),
        _stat(Icons.bolt_rounded, '$activeCount', 'Active',
            FlixieColors.tertiary),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSearchField extends StatelessWidget {
  const _GroupSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: FlixieColors.light, fontSize: 14),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search groups',
        hintStyle: const TextStyle(color: FlixieColors.medium),
        prefixIcon:
            const Icon(Icons.search_rounded, color: FlixieColors.medium),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon:
                    const Icon(Icons.close_rounded, color: FlixieColors.medium),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: FlixieColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlixieColors.primary),
        ),
      ),
    );
  }
}

class _NoGroupsCard extends StatelessWidget {
  const _NoGroupsCard({
    required this.isSearching,
    required this.onCreateGroup,
  });

  final bool isSearching;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.groups_2_outlined,
            color: FlixieColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSearching
                  ? 'No groups match your search.'
                  : 'Create a group to plan watches with friends.',
              style: const TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
          ),
          if (!isSearching)
            TextButton(
              onPressed: onCreateGroup,
              child: const Text('Create'),
            ),
        ],
      ),
    );
  }
}

class _NoGroupInvitesCard extends StatelessWidget {
  const _NoGroupInvitesCard({required this.onCreateGroup});

  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No pending invites',
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a group and invite friends to plan what to watch next.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onCreateGroup,
            icon: const Icon(Icons.add),
            label: const Text('Create group'),
            style: FilledButton.styleFrom(
              foregroundColor: FlixieColors.light,
              backgroundColor: FlixieColors.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingGroupInviteSummary extends StatelessWidget {
  const _PendingGroupInviteSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlixieColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, color: FlixieColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count group invite${count == 1 ? '' : 's'} waiting',
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Groups inner tab bar
// ---------------------------------------------------------------------------

class _GroupsTabBar extends StatelessWidget {
  const _GroupsTabBar({
    required this.selectedIndex,
    required this.pendingCount,
    required this.onChanged,
  });

  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _tab(0, 'Groups'),
          const SizedBox(width: 8),
          _tab(1, 'Invites'),
        ],
      ),
    );
  }

  Widget _tab(int index, String label) {
    final selected = index == selectedIndex;
    final showBadge = index == 1 && pendingCount > 0;
    return GestureDetector(
      onTap: () => onChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? FlixieColors.primary
              : FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? FlixieColors.primary : FlixieColors.tabBarBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : FlixieColors.medium,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FlixieColors.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create group bottom sheet
// ---------------------------------------------------------------------------

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({this.onCreated});

  final void Function(Group)? onCreated;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _abbrController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPublic = true;

  // Step 1 — add members (before creation)
  int _step = 0;
  List<FriendshipUser> _friends = [];
  final List<String> _selectedFriendIds = [];
  bool _loadingFriends = false;
  bool _inviting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    _loadFriendsForInvite(userId);
    setState(() => _step = 1);
  }

  Future<void> _createGroupWithMembers() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    setState(() => _inviting = true);
    try {
      final members = [
        {'memberId': userId, 'role': 'OWNER', 'inviteStatus': 'ACCEPTED'},
        ..._selectedFriendIds.map((id) => {
              'memberId': id,
              'role': 'MEMBER',
              'inviteStatus': 'PENDING',
            }),
      ];
      final group = await GroupService.createGroup({
        'name': _nameController.text.trim(),
        if (_abbrController.text.trim().isNotEmpty)
          'abbreviation': _abbrController.text.trim(),
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        'visibility': _isPublic ? 'PUBLIC' : 'PRIVATE',
        'ownerId': userId,
        'members': members,
      });
      widget.onCreated?.call(group);
    } catch (e) {
      logger.e('Create group error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group')),
        );
        setState(() => _inviting = false);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _loadFriendsForInvite(String userId) async {
    if (mounted) setState(() => _loadingFriends = true);
    try {
      final data = await _friendActions.getFriends(userId);
      if (mounted) {
        setState(() {
          _friends = data.friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .toList();
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _step == 0
          ? _buildFormStep(scrollController, textTheme)
          : _buildInviteStep(scrollController),
    );
  }

  Widget _buildFormStep(
      ScrollController scrollController, TextTheme textTheme) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create Group',
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _inputField(
              controller: _nameController,
              label: 'Group Name *',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _abbrController,
              label: 'Abbreviation (optional, max 4 chars)',
              maxLength: 4,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _descController,
              label: 'Description (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Visibility',
              style: textTheme.bodyMedium
                  ?.copyWith(color: FlixieColors.light, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                VisibilityChip(
                  label: 'Public',
                  selected: _isPublic,
                  onTap: () => setState(() => _isPublic = true),
                ),
                const SizedBox(width: 10),
                VisibilityChip(
                  label: 'Private',
                  selected: !_isPublic,
                  onTap: () => setState(() => _isPublic = false),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Next',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteStep(ScrollController scrollController) {
    final query = _searchController.text.toLowerCase();
    final filtered = _friends.where((f) {
      return f.username.toLowerCase().contains(query) ||
          (f.firstName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: FlixieColors.medium.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Members',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'to "${_nameController.text}"',
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _inviting ? null : _createGroupWithMembers,
                child: const Text('Skip',
                    style: TextStyle(color: FlixieColors.medium)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: FlixieColors.light),
            decoration: InputDecoration(
              hintText: 'Search friends…',
              hintStyle: const TextStyle(color: FlixieColors.medium),
              prefixIcon: const Icon(Icons.search, color: FlixieColors.medium),
              filled: true,
              fillColor: FlixieColors.tabBarBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingFriends
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        _friends.isEmpty
                            ? 'No friends to invite yet'
                            : 'No matches',
                        style: const TextStyle(color: FlixieColors.medium),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final friend = filtered[i];
                        final selected = _selectedFriendIds.contains(friend.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _selectedFriendIds.add(friend.id);
                            } else {
                              _selectedFriendIds.remove(friend.id);
                            }
                          }),
                          title: Text(friend.username,
                              style:
                                  const TextStyle(color: FlixieColors.light)),
                          subtitle: friend.firstName != null
                              ? Text(friend.firstName!,
                                  style: const TextStyle(
                                      color: FlixieColors.medium, fontSize: 12))
                              : null,
                          activeColor: FlixieColors.primary,
                          checkColor: Colors.black,
                          secondary: CircleAvatar(
                            backgroundColor:
                                FlixieColors.primary.withValues(alpha: 0.2),
                            child: Text(
                              friend.username[0].toUpperCase(),
                              style: const TextStyle(
                                color: FlixieColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _inviting ? null : _createGroupWithMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _inviting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      _selectedFriendIds.isEmpty
                          ? 'Create Group'
                          : 'Create & Invite ${_selectedFriendIds.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: FlixieColors.light),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: FlixieColors.medium, fontSize: 13),
        counterStyle: const TextStyle(color: FlixieColors.medium),
        filled: true,
        fillColor: FlixieColors.tabBarBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.primary),
        ),
      ),
    );
  }
}
