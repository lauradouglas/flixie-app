import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_lookup_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key, this.onRequestSent});

  final void Function(FriendshipUser user)? onRequestSent;

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final ProfileLookupController _profileLookup =
      ProfileLookupController.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  List<User> _results = [];
  String? _searchError;
  final Set<String> _sentRequests = {};
  final Set<String> _friends = {}, _incoming = {};

  Future<void> _relationships(String viewer) async {
    final data = await _friendActions.getFriends(viewer);
    if (!mounted || context.read<AuthProvider>().dbUser?.id != viewer) return;
    Set<String> ids(List<Friendship> rows) => rows
        .expand((row) => [
              row.friendId,
              row.friend?.id,
              row.recipient?.id,
              row.requester?.id,
            ])
        .whereType<String>()
        .where((id) => id != viewer)
        .toSet();
    setState(() {
      _friends
        ..clear()
        ..addAll(ids(data.friendships));
      _incoming
        ..clear()
        ..addAll(ids(data.pendingFriends));
      _sentRequests.addAll(ids(data.requestedFriends));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searching) return;

    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
    });

    try {
      final auth = context.read<AuthProvider>();
      final myId = auth.dbUser?.id;
      if (myId == null) {
        setState(() => _searching = false);
        return;
      }
      await _relationships(myId);

      List<User> results;

      // Try the search endpoint first; fall back to exact username lookup.
      try {
        results = await _profileLookup.searchUsers(query);
      } catch (_) {
        try {
          final user = await _profileLookup.getUserByUsername(query);
          results = [user];
        } catch (_) {
          results = [];
        }
      }

      // Exclude the current user from results.
      results = results.where((u) => u.id != myId).toList();

      if (mounted && context.read<AuthProvider>().dbUser?.id == myId) {
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
    final analytics = context.read<AnalyticsController>();
    final myId = auth.dbUser?.id;
    if (myId == null ||
        _friends.contains(user.id) ||
        _incoming.contains(user.id) ||
        _sentRequests.contains(user.id)) {
      return;
    }

    setState(() => _sentRequests.add(user.id));

    try {
      await _relationships(myId);
      if (!mounted || context.read<AuthProvider>().dbUser?.id != myId) return;
      if (_friends.contains(user.id) || _incoming.contains(user.id)) {
        setState(() => _sentRequests.remove(user.id));
        return;
      }
      await _friendActions.sendFriendRequest({
        'requesterId': myId,
        'recipientId': user.id,
        'responderUsername': user.username,
        'message': '',
        'type': 'FRIEND_REQUEST',
      });
      await analytics.friendRequestSent();
      // Notify parent so the Sent tab updates immediately
      widget.onRequestSent?.call(
        FriendshipUser(
          id: user.id,
          username: user.username,
          firstName: user.firstName,
          initials: user.initials,
          iconColor: user.iconColor,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content: Text('Friend request sent to ${user.username}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sentRequests.remove(user.id));
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to send friend request')),
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
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * .85),
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: context.colors.medium
                                        .withValues(alpha: .4),
                                    borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Expanded(
                              child: Text('Add a friend',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700))),
                          IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close)),
                        ]),
                        Text('Search for someone by their username.',
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: context.colors.light)),
                        const SizedBox(height: 16),
                        TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 14),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _search(),
                            decoration: InputDecoration(
                                hintText: 'Username',
                                prefixIcon: Icon(Icons.search,
                                    size: 20, color: context.colors.light),
                                filled: true,
                                fillColor: context.colors.surfaceElevated,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                suffixIcon: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: IconButton.filled(
                                        tooltip: 'Search',
                                        onPressed: _searching ? null : _search,
                                        style: IconButton.styleFrom(
                                            backgroundColor:
                                                FlixieColors.primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(44, 44)),
                                        icon: _searching
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : const Icon(Icons.arrow_forward,
                                                size: 20))))),
                        if (_searchError != null) ...[
                          const SizedBox(height: 16),
                          Text(_searchError!,
                              style: TextStyle(
                                  fontSize: 14, color: context.colors.light)),
                        ],
                        if (_results.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final user in _results) _result(user),
                          const SizedBox(height: 12),
                          Text('Send a request to connect on Flixie.',
                              style: TextStyle(
                                  fontSize: 12, color: context.colors.light)),
                        ],
                      ])),
            ),
          ));

  Widget _result(User user) {
    final sent = _sentRequests.contains(user.id);
    final identity = Row(children: [
      Padding(
          padding: const EdgeInsets.all(4),
          child: ProfileAvatarView(
              avatar: user.avatar,
              profileBadges: user.profileBadges,
              fallbackText: user.initials ??
                  (user.username.isEmpty
                      ? '?'
                      : user.username[0].toUpperCase()),
              fallbackColor: _userAvatarColor(user),
              size: 36)),
      const SizedBox(width: 10),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            user.firstName?.isNotEmpty == true
                ? user.firstName!
                : user.username,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('@${user.username}',
            style: TextStyle(fontSize: 12, color: context.colors.light)),
      ])),
    ]);
    final action = _friends.contains(user.id) ||
            _incoming.contains(user.id) ||
            sent
        ? Text(
            _friends.contains(user.id)
                ? 'Already friends'
                : _incoming.contains(user.id)
                    ? 'Request received'
                    : 'Request sent',
            style: TextStyle(fontSize: 12, color: context.colors.success))
        : FilledButton(
            onPressed: () => _sendRequest(user),
            style: FilledButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Add friend', style: TextStyle(fontSize: 13)));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: action)
                ]);
          }
          return Row(children: [
            Expanded(child: identity),
            const SizedBox(width: 12),
            action
          ]);
        }));
  }
}
