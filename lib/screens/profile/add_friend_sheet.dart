import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friendship.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/friend_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key, this.onRequestSent});

  final void Function(FriendshipUser user)? onRequestSent;

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  List<User> _results = [];
  String? _searchError;
  final Set<String> _sentRequests = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
    });

    try {
      final auth = context.read<AuthProvider>();
      final myId = auth.dbUser?.id;

      List<User> results;

      // Try the search endpoint first; fall back to exact username lookup.
      try {
        results = await UserService.searchUsers(query);
      } catch (_) {
        try {
          final user = await UserService.getUserByUsername(query);
          results = [user];
        } catch (_) {
          results = [];
        }
      }

      // Exclude the current user from results.
      if (myId != null) {
        results = results.where((u) => u.id != myId).toList();
      }

      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
          if (results.isEmpty) _searchError = 'No users found.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = 'Search failed. Please try again.';
        });
      }
    }
  }

  Future<void> _sendRequest(User user) async {
    final auth = context.read<AuthProvider>();
    final myId = auth.dbUser?.id;
    if (myId == null) return;

    setState(() => _sentRequests.add(user.id));

    try {
      await FriendService.sendFriendRequest({
        'requesterId': myId,
        'recipientId': user.id,
        'responderUsername': user.username,
        'message': '',
        'type': 'FRIEND_REQUEST',
      });
      // Notify parent so the Sent tab updates immediately
      widget.onRequestSent?.call(
        FriendshipUser(
          id: user.id,
          username: user.username,
          firstName: user.firstName,
          lastName: user.lastName,
          initials: user.initials,
          iconColor: user.iconColor,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to ${user.username}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sentRequests.remove(user.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send friend request')),
        );
      }
    }
  }

  Color _userAvatarColor(User user) {
    final hex = user.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
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
            child: Text(
              'Add Friend',
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Search by username or email',
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: FlixieColors.light),
                    decoration: InputDecoration(
                      hintText: 'Username or email…',
                      hintStyle: const TextStyle(color: FlixieColors.medium),
                      prefixIcon:
                          const Icon(Icons.search, color: FlixieColors.medium),
                      filled: true,
                      fillColor: FlixieColors.tabBarBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlixieColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _results.isEmpty && _searchError != null
                ? Center(
                    child: Text(
                      _searchError!,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FlixieColors.medium),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final user = _results[i];
                      final sent = _sentRequests.contains(user.id);
                      final color = _userAvatarColor(user);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.25),
                          child: Text(
                            user.initials ??
                                (user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?'),
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(user.username,
                            style: const TextStyle(color: FlixieColors.light)),
                        subtitle: Text(
                          user.email,
                          style: const TextStyle(
                              color: FlixieColors.medium, fontSize: 12),
                        ),
                        trailing: sent
                            ? const Icon(Icons.check_circle,
                                color: FlixieColors.success)
                            : ElevatedButton(
                                onPressed: () => _sendRequest(user),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FlixieColors.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('Add'),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
