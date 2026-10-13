import 'package:flutter/material.dart';
import 'package:flixie_app/models/friendship.dart';
import '../../data/starred_people.dart';
import '../utils/friend_selection.dart';

/// Shared filter and private starred-first ordering for friend selection surfaces.
class FriendSearchScope<T> extends StatefulWidget {
  const FriendSearchScope(
      {super.key,
      required this.items,
      required this.userOf,
      required this.builder,
      this.expanded = false});
  final bool expanded;
  final Iterable<T> items;
  final FriendshipUser? Function(T) userOf;
  final Widget Function(BuildContext, List<T>) builder;
  @override
  State<FriendSearchScope<T>> createState() => _FriendSearchScopeState<T>();
}

class _FriendSearchScopeState<T> extends State<FriendSearchScope<T>> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: StarredPeople.instance,
      builder: (context, _) {
        final visible = selectFriends(widget.items,
            userOf: widget.userOf,
            starred: StarredPeople.instance.ids,
            query: _search.text);
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      hintText: 'Search friends',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded)))),
              const SizedBox(height: 10),
              if (visible.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No friends match your search.'))
              else if (widget.expanded)
                Expanded(child: widget.builder(context, visible))
              else
                widget.builder(context, visible),
            ]);
      });
}

/// Existing search surfaces keep their own query while subscribing to star changes.
mixin StarredFriendsState<T extends StatefulWidget> on State<T> {
  void _starsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    StarredPeople.instance.addListener(_starsChanged);
  }

  @override
  void dispose() {
    StarredPeople.instance.removeListener(_starsChanged);
    super.dispose();
  }

  List<V> orderedFriends<V>(
          Iterable<V> items, FriendshipUser? Function(V) userOf,
          [String query = '']) =>
      selectFriends(items,
          userOf: userOf, starred: StarredPeople.instance.ids, query: query);
}
