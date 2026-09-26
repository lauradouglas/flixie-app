import 'package:flutter/material.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../controllers/friend_actions_controller.dart';
import '../../data/community_service.dart';

class CommunityListEditors extends StatefulWidget {
  const CommunityListEditors(
      {super.key,
      required this.listId,
      required this.userId,
      required this.service});
  final String listId, userId;
  final CommunityService service;
  @override
  State<CommunityListEditors> createState() => _CommunityListEditorsState();
}

class _CommunityListEditorsState extends State<CommunityListEditors> {
  List<FriendshipUser> _friends = [];
  List<Map<String, dynamic>> _editors = [];
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final friends =
          await const FriendActionsController().getFriends(widget.userId);
      final editors = await widget.service.editors(widget.listId);
      if (mounted) {
        setState(() {
          _friends = friends.friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .toList();
          _editors = editors;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load editors.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(String userId, String action) async {
    setState(() => _busy = true);
    try {
      await widget.service.invitation(widget.listId, userId, action);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t update this invitation. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _avatar(FriendshipUser user) => SizedBox(
      width: 48,
      height: 48,
      child: Center(
          child: ProfileAvatarView(
              avatar: user.avatar,
              profileBadges: user.profileBadges,
              size: 32,
              fallbackText: user.username.isEmpty ? '?' : user.username[0],
              fallbackColor: Theme.of(context).colorScheme.primary)));

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('List editors', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Invite friends to add and remove titles. They must accept before they can edit. You keep control of the list’s name, visibility and editors.'),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          TextButton(onPressed: _load, child: Text('$_error Retry')),
        for (final entry in _editors)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _avatar(FriendshipUser.fromJson(
                  Map<String, dynamic>.from(entry['user']))),
              title: Text(entry['user']['username'] as String),
              subtitle: Text(entry['status'] == 'ACCEPTED'
                  ? 'Editor'
                  : entry['status'] == 'PENDING'
                      ? 'Invitation pending'
                      : 'Declined'),
              trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _action(entry['user']['id'] as String, 'remove'),
                  child: const Text('Remove'))),
        for (final user in _friends
            .where((f) => !_editors.any((e) => e['user']['id'] == f.id)))
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                      child: ProfileAvatarView(
                          avatar: user.avatar,
                          profileBadges: user.profileBadges,
                          size: 32,
                          fallbackText:
                              user.username.isEmpty ? '?' : user.username[0],
                          fallbackColor:
                              Theme.of(context).colorScheme.primary))),
              title: Text(user.username),
              trailing: TextButton(
                  onPressed: _busy ? null : () => _action(user.id, 'invite'),
                  child: const Text('Invite'))),
        if (!_loading && _friends.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Add people as friends to invite them to edit.')),
      ]);
}
