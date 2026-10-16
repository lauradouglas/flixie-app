import 'package:flixie_app/features/movies/models/external_watch_invite.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/friend_search_scope.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';

class WatchCompanionPicker extends StatefulWidget {
  const WatchCompanionPicker(
      {super.key,
      required this.loadFriends,
      this.selected = const [],
      this.lockedIds = const {}});
  final List<FriendshipUser> selected;
  final Set<String> lockedIds;
  final Future<List<Friendship>> Function() loadFriends;
  @override
  State<WatchCompanionPicker> createState() => _WatchCompanionPickerState();
}

class _WatchCompanionPickerState extends State<WatchCompanionPicker> {
  late Future<List<Friendship>> _friends;
  final _name = TextEditingController();
  bool _external = false;
  late Map<String, FriendshipUser> _selected;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selected = {for (final friend in widget.selected) friend.id: friend};
    _friends = widget.loadFriends();
    if (!StarredPeople.instance.loaded) {
      StarredPeople.instance.refresh().catchError((Object _) {});
    }
  }

  Widget _header() => Row(children: [
        Expanded(
            child: Text(_external ? 'Someone new to Flixie' : 'Watched with…',
                style: Theme.of(context).textTheme.titleLarge)),
        IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close))
      ]);
  Widget _externalForm() => ListView(children: [
        _header(),
        const SizedBox(height: 12),
        const Text(
            'Their name stays on your watch. After saving, you can share an invite for them to join and log their own watch.'),
        const SizedBox(height: 16),
        TextField(
            controller: _name,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Their name'),
            onChanged: (_) => setState(() {})),
        FilledButton(
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                    context, ExternalWatchCompanion(_name.text.trim())),
            child: const Text('Add to my watch')),
        TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              setState(() => _external = false);
            },
            child: const Text('Back to friends')),
      ]);
  Widget _friendsList() => FutureBuilder<List<Friendship>>(
      future: _friends,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Couldn’t load your friends.'),
            TextButton(
                onPressed: () =>
                    setState(() => _friends = widget.loadFriends()),
                child: const Text('Retry'))
          ]));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
              child: Text('Choose someone new to Flixie below.'));
        }
        return FriendSearchScope<Friendship>(
            items: snapshot.data!,
            userOf: (f) => f.friendUser,
            expanded: true,
            builder: (context, friends) => ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index].friendUser!;
                  return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: 4),
                      leading: ProfileAvatarView(
                          avatar: friend.avatar,
                          profileBadges: friend.profileBadges,
                          fallbackText: friend.displayName,
                          fallbackColor:
                              avatarColorFromIconColor(friend.iconColor),
                          size: 44),
                      title: Text(friend.displayName),
                      subtitle: widget.lockedIds.contains(friend.id)
                          ? const Text('Already linked to this watch')
                          : null,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (StarredPeople.instance.ids.contains(friend.id))
                          Icon(Icons.star_rounded,
                              color: context.colors.warning),
                        Checkbox(
                            value: _selected.containsKey(friend.id),
                            onChanged: widget.lockedIds.contains(friend.id)
                                ? null
                                : (_) => _toggle(friend)),
                      ]),
                      onTap: widget.lockedIds.contains(friend.id)
                          ? null
                          : () => _toggle(friend));
                }));
      });
  void _toggle(FriendshipUser friend) {
    setState(() {
      if (_selected.containsKey(friend.id)) {
        _selected.remove(friend.id);
      } else if (_selected.length < 20) {
        _selected[friend.id] = friend;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height;
    final compact = keyboard > 0 && height - keyboard < 300;
    return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Material(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
                height:
                    (height - keyboard - MediaQuery.paddingOf(context).top) *
                        (keyboard > 0 ? 1 : .8),
                child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20, compact ? 4 : 8, 20, compact ? 4 : 12),
                    child: _external
                        ? _externalForm()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                if (!compact) _header(),
                                if (!compact) const SizedBox(height: 8),
                                Expanded(child: _friendsList()),
                                if (keyboard == 0 && _selected.isEmpty)
                                  TextButton.icon(
                                      onPressed: () =>
                                          setState(() => _external = true),
                                      icon: const Icon(
                                          Icons.person_add_alt_1_outlined),
                                      label: const Text(
                                          'Someone who isn’t on Flixie')),
                                const SizedBox(height: 8),
                                FilledButton(
                                    onPressed: () => Navigator.pop(
                                        context, _selected.values.toList()),
                                    child: Text(_selected.isEmpty || compact
                                        ? 'Done'
                                        : 'Done · ${_selected.length} selected')),
                              ])))));
  }
}
