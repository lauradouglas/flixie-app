import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import '../widgets/people_directory.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/add_friend_sheet.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/pending_friend_card.dart';

import '../controllers/social_people_controller.dart';

class SocialPeopleView extends StatefulWidget {
  const SocialPeopleView({super.key, this.active = true});
  final bool active;

  @override
  State<SocialPeopleView> createState() => _SocialPeopleViewState();
}

class _SocialPeopleViewState extends State<SocialPeopleView> {
  late final SocialPeopleController _controller;
  FriendsData? get _friendsData => _controller.data;
  bool get _loading => _controller.loading;
  String? get _error => _controller.error;
  @override
  void initState() {
    super.initState();
    _controller = SocialPeopleController(auth: context.read<AuthProvider>());
    _controller.addListener(_changed);
    _controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() => _controller.load();
  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  void _showAddFriendSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddFriendSheet(),
    );
  }

  Future<void> _acceptRequest(Friendship friendship) async {
    final success = await _controller.respond(friendship, accept: true);
    if (!mounted || success == null) return;
    ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: success ? FlixieToastType.success : FlixieToastType.error,
        content: Text(success
            ? 'Now friends with ${friendship.friendUser?.username ?? 'user'}'
            : 'Failed to accept friend request')));
  }

  Future<void> _declineRequest(Friendship friendship) async {
    final success = await _controller.respond(friendship, accept: false);
    if (!mounted || success != false) return;
    ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: const Text('Failed to decline friend request')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ContentListSkeleton();
    }

    if (_error != null) {
      return FlixieRefresh(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(_error!,
                    style: TextStyle(color: context.colors.medium)),
              ),
            ),
          ],
        ),
      );
    }

    final data = _friendsData;
    final friends = data?.friendships
            .map((f) => f.friendUser)
            .whereType<FriendshipUser>()
            .toList() ??
        const <FriendshipUser>[];

    return FlixieRefresh(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PeopleDirectory(
              active: widget.active,
              userId: context.read<AuthProvider>().dbUser?.id ?? '',
              friends: friends,
            ),
            const SizedBox(height: 16),
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
              const SizedBox(height: 14),
            ],
            TextButton.icon(
              onPressed: () => context.go('/social?tab=activity'),
              icon: const Icon(Icons.dynamic_feed_outlined),
              label: const Text('Explore activity'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friends widgets
// ---------------------------------------------------------------------------

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
              style: TextStyle(
                color: context.colors.light,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onAddFriend,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primaryText,
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
