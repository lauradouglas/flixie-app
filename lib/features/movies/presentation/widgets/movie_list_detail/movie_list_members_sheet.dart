import 'package:flutter/material.dart';

import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class MovieListMembersSheet extends StatelessWidget {
  const MovieListMembersSheet(
      {super.key,
      required this.membership,
      required this.onAdd,
      required this.onRemove,
      required this.onLeave});
  final MovieListMembership membership;
  final VoidCallback onAdd;
  final ValueChanged<MovieListMember> onRemove;
  final VoidCallback onLeave;
  @override
  Widget build(BuildContext sheetContext) {
    final context = sheetContext;
    return SafeArea(
        child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${membership.members.length} member${membership.members.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: context.colors.light,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (membership.canManageMembers)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...membership.members.map(
              (member) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ProfileAvatarView(
                  avatar: member.avatar,
                  fallbackText: member.username.isEmpty
                      ? '?'
                      : member.username[0].toUpperCase(),
                  fallbackColor: FlixieColors.primary,
                  size: 40,
                  profileBadges: member.profileBadges,
                ),
                title: Text('@${member.username}'),
                subtitle: member.id == membership.ownerId
                    ? const Text('Owner')
                    : null,
                trailing: membership.canManageMembers &&
                        member.id != membership.ownerId
                    ? IconButton(
                        tooltip: 'Remove member',
                        onPressed: () => onRemove(member),
                        icon: Icon(
                          Icons.person_remove_outlined,
                          color: context.colors.danger,
                        ),
                      )
                    : null,
              ),
            ),
            if (membership.canLeave)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    onLeave();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Leave list'),
                ),
              ),
          ],
        ),
      ),
    ));
  }
}
