import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class PickPeoplePicker extends StatefulWidget {
  const PickPeoplePicker(
      {super.key,
      required this.company,
      required this.friends,
      required this.groups,
      required this.loading,
      required this.error,
      required this.friendId,
      required this.groupId,
      required this.onRetry,
      required this.onFriend,
      required this.onGroup});
  final String company;
  final List<Friendship> friends;
  final List<Group> groups;
  final bool loading;
  final String? error, friendId, groupId;
  final VoidCallback onRetry;
  final ValueChanged<String> onFriend, onGroup;
  @override
  State<PickPeoplePicker> createState() => _PickPeoplePickerState();
}

class _PickPeoplePickerState extends State<PickPeoplePicker> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _note(String text) =>
      Text(text, style: TextStyle(color: context.colors.medium, height: 1.5));
  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final friends = widget.friends
        .map((f) => f.friendUser)
        .whereType<FriendshipUser>()
        .where((f) => f.displayName.toLowerCase().contains(query))
        .toList();
    final groups = widget.groups
        .where((g) => g.name.toLowerCase().contains(query))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      if (widget.loading) const LinearProgressIndicator(),
      if (widget.error != null) ...[
        _note(widget.error!),
        TextButton(
            onPressed: widget.loading ? null : widget.onRetry,
            child: const Text('Retry viewers')),
      ],
      TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText:
                  widget.company == 'friend' ? 'Find a friend' : 'Find a group',
              prefixIcon: const Icon(Icons.search))),
      const SizedBox(height: 8),
      if (!widget.loading &&
          (widget.company == 'friend' ? friends.isEmpty : groups.isEmpty))
        _note(query.isNotEmpty
            ? 'No matches. Try another name.'
            : widget.error != null
                ? 'Your saved viewers will appear here when loading succeeds.'
                : widget.company == 'friend'
                    ? 'No friends yet. You can pick solo, or add friends in Social.'
                    : 'No groups yet. You can pick solo, or create a group in Social.'),
      ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .3),
          child: ListView(
            shrinkWrap: true,
            primary: false,
            children: widget.company == 'friend'
                ? [
                    for (final friend in friends)
                      Semantics(
                          selected: widget.friendId == friend.id,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            leading: ProfileAvatarView(
                                avatar: friend.avatar,
                                profileBadges: friend.profileBadges,
                                fallbackText:
                                    friend.initials ?? friend.displayName,
                                fallbackColor: FlixieColors.primary,
                                size: 40),
                            title: Text(friend.displayName),
                            trailing: Icon(widget.friendId == friend.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                            onTap: () => widget.onFriend(friend.id),
                          )),
                  ]
                : [
                    for (final group in groups)
                      Semantics(
                          selected: widget.groupId == group.id,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(group.name),
                            subtitle:
                                const Text('Accepted members · 2–12 viewers'),
                            trailing: Icon(widget.groupId == group.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                            onTap: () => widget.onGroup(group.id!),
                          )),
                  ],
          )),
    ]);
  }
}
