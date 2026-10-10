import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/models/movie_list.dart';
import '../../controllers/list_editor_relationships.dart';
import 'list_editor_layout.dart';

class ListCollaboratorPicker extends StatelessWidget {
  const ListCollaboratorPicker(
      {super.key,
      required this.isEdit,
      required this.initialScope,
      required this.scope,
      required this.groupId,
      required this.selectedFriends,
      required this.relationships,
      required this.onScope,
      required this.onGroup,
      required this.onFriend});
  final bool isEdit;
  final String initialScope, scope;
  final String? groupId;
  final Set<String> selectedFriends;
  final ListEditorRelationships relationships;
  final ValueChanged<String> onScope;
  final ValueChanged<String?> onGroup;
  final void Function(String, bool) onFriend;

  @override
  Widget build(BuildContext context) {
    final lockedGroup = isEdit && initialScope == ListScope.group;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isEdit)
        DropdownButtonFormField<String>(
          initialValue: scope,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Who can add to this list'),
          items: lockedGroup
              ? const [
                  DropdownMenuItem(
                      value: ListScope.group, child: Text('Group members'))
                ]
              : const [
                  DropdownMenuItem(
                      value: ListScope.personal, child: Text('Just me')),
                  DropdownMenuItem(
                      value: ListScope.friends,
                      child: Text('Selected friends')),
                  DropdownMenuItem(
                      value: ListScope.group, child: Text('With a group')),
                ],
          onChanged: lockedGroup
              ? null
              : (value) => onScope(value ?? ListScope.personal),
        )
      else
        ListChoiceGroup(
            value: scope,
            title: 'Who’s making it?',
            items: const [
              DropdownMenuItem(
                  value: ListScope.personal, child: Text('Just me')),
              DropdownMenuItem(
                  value: ListScope.friends, child: Text('With friends')),
              DropdownMenuItem(
                  value: ListScope.group, child: Text('With a group')),
            ],
            onChanged: (value) => onScope(value ?? ListScope.personal)),
      if (scope == ListScope.friends) ...[
        const SizedBox(height: 12),
        const Text('Choose friends',
            style: TextStyle(fontWeight: FontWeight.w700)),
        if (relationships.loadingFriends)
          const LinearProgressIndicator(semanticsLabel: 'Loading friends')
        else if (relationships.friendsError != null)
          TextButton(
              onPressed: () => relationships.load(scope),
              child: Text(relationships.friendsError!))
        else if (relationships.friends.isEmpty)
          const Text('No accepted friends available.')
        else
          _FriendsPicker(
              relationships: relationships,
              selected: selectedFriends,
              onChanged: onFriend),
      ],
      if (scope == ListScope.group && !lockedGroup) ...[
        const SizedBox(height: 12),
        if (relationships.loadingGroups)
          const LinearProgressIndicator(semanticsLabel: 'Loading groups')
        else if (relationships.groupsError != null)
          TextButton(
              onPressed: () => relationships.load(scope),
              child: Text(relationships.groupsError!))
        else if (relationships.groups.isEmpty)
          const Text('No groups available.')
        else
          DropdownButtonFormField<String>(
            initialValue: groupId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Choose group'),
            items: relationships.groups
                .where((g) => g.id != null)
                .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
                .toList(),
            onChanged: onGroup,
          ),
      ],
      if (lockedGroup)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Group lists cannot be changed to solo lists.')),
    ]);
  }
}

class _FriendsPicker extends StatefulWidget {
  const _FriendsPicker(
      {required this.relationships,
      required this.selected,
      required this.onChanged});
  final ListEditorRelationships relationships;
  final Set<String> selected;
  final void Function(String, bool) onChanged;
  @override
  State<_FriendsPicker> createState() => _FriendsPickerState();
}

class _FriendsPickerState extends State<_FriendsPicker> {
  String query = '';
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final friends = widget.relationships.friends.where((f) =>
        '${f.username} ${f.firstName ?? ''} ${f.lastName ?? ''}'
            .toLowerCase()
            .contains(q));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
          controller: search,
          onChanged: (value) => setState(() => query = value),
          decoration: InputDecoration(
              hintText: 'Search friends',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        search.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close_rounded)))),
      const SizedBox(height: 10),
      if (friends.isEmpty)
        const Text('No friends match your search.')
      else
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final friend in friends)
            FlixiePill.filter(
                label: Text('@${friend.username}'),
                selected: widget.selected.contains(friend.id),
                onSelected: (value) => widget.onChanged(friend.id, value)),
        ]),
    ]);
  }
}
