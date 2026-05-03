import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_list_item.dart';
import '../../models/friendship.dart';
import '../../providers/auth_provider.dart';
import '../profile/activity_tile.dart';
import '../profile/friends_row.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import 'pending_friend_card.dart';
import 'section_header.dart';

class FriendsSubView extends StatefulWidget {
  const FriendsSubView();

  @override
  State<FriendsSubView> createState() => _FriendsSubViewState();
}

class _FriendsSubViewState extends State<FriendsSubView> {
  bool _loading = true;
  FriendsData? _friendsData;
  List<ActivityListItem> _activity = [];
  String? _error;

  @override
  void initState() {
    super.initState();
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
        FriendService.getFriends(userId),
        FriendService.getFriendsActivityLists(userId),
      ]);
      if (mounted) {
        setState(() {
          _friendsData = results[0] as FriendsData;
          _activity = results[1] as List<ActivityListItem>;
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

  Future<void> _acceptRequest(Friendship friendship) async {
    try {
      await FriendService.updateRequest(friendship.id, 'ACCEPTED');
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
          FriendService.getFriendsActivityLists(userId).then((activity) {
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
      await FriendService.updateRequest(friendship.id, 'DECLINED');
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
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending requests section
            if (data != null && data.pendingFriends.isNotEmpty) ...[
              SocialSectionHeader(
                title: 'PENDING REQUESTS',
                badge: data.pendingFriends.length,
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
              FriendsRow(
                data: data,
                onFriendsChanged: (updated) =>
                    setState(() => _friendsData = updated),
              ),
              const SizedBox(height: 16),
            ],

            // Activity section
            const SocialSectionHeader(title: 'FRIENDS ACTIVITY'),
            const SizedBox(height: 8),
            if (_activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recent activity.',
                  style:
                      textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activity.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ActivityTile(item: _activity[i]),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
