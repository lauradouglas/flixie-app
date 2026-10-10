import 'package:flutter/material.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class AddListMemberSheet extends StatefulWidget {
  const AddListMemberSheet({super.key, required this.friends});

  final List<FriendshipUser> friends;

  @override
  State<AddListMemberSheet> createState() => AddListMemberSheetState();
}

class AddListMemberSheetState extends State<AddListMemberSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.friends
        : widget.friends
            .where((friend) => [
                  friend.username,
                  friend.firstName ?? '',
                  friend.lastName ?? '',
                ].join(' ').toLowerCase().contains(query))
            .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a friend',
              style: TextStyle(
                color: context.colors.light,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search friends',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No friends available to add.',
                    style: TextStyle(color: context.colors.medium),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (_, index) {
                    final friend = visible[index];
                    return ListTile(
                      onTap: () => Navigator.pop(context, friend),
                      leading: ProfileAvatarView(
                        avatar: friend.avatar,
                        fallbackText: friend.username.isEmpty
                            ? '?'
                            : friend.username[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 38,
                        profileBadges: friend.profileBadges,
                      ),
                      title: Text('@${friend.username}'),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
