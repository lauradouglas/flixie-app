import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import '../../controllers/watch_composer_controller.dart';
import 'composer_components.dart';
import 'composer_recipient_tile.dart';

class ComposerRecipients extends StatefulWidget {
  const ComposerRecipients({super.key, required this.controller});
  final WatchComposerController controller;
  @override
  State<ComposerRecipients> createState() => _ComposerRecipientsState();
}

class _ComposerRecipientsState extends State<ComposerRecipients> {
  final _recipientSearchController = TextEditingController();
  String _recipientSearch = '';
  @override
  void dispose() {
    _recipientSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _recipientSearch.toLowerCase();
    final visibleFriends = controller.friends.where((item) {
      final friend = item.friendUser;
      if (friend == null) return false;
      return query.isEmpty || friend.displayName.toLowerCase().contains(query);
    }).toList();
    final visibleGroups = controller.groups
        .where((group) =>
            query.isEmpty ||
            group.name.toLowerCase().contains(query) ||
            (group.abbreviation?.toLowerCase().contains(query) ?? false))
        .toList();
    final hasFriends =
        controller.friends.any((item) => item.friendUser != null);
    final hasGroups = controller.groups.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PlanStepHeading(number: '1', title: 'Who’s watching?'),
      const SizedBox(height: 10),
      // Friend / Group toggle
      Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          border: Border.all(color: context.colors.tabBarBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: ModeTab(
                label: 'A Friend',
                icon: Icons.person_outline_rounded,
                selected: !controller.isGroupMode,
                onTap: () => controller.setGroupMode(false),
              ),
            ),
            Expanded(
              child: ModeTab(
                label: 'A Group',
                icon: Icons.groups_2_outlined,
                selected: controller.isGroupMode,
                onTap: () => controller.setGroupMode(true),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if ((controller.isGroupMode ? hasGroups : hasFriends)) ...[
        TextField(
          controller: _recipientSearchController,
          onChanged: (value) => setState(() => _recipientSearch = value.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: controller.isGroupMode
                ? 'Search your groups'
                : 'Search friends',
            suffixIcon: _recipientSearch.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _recipientSearchController.clear();
                      setState(() => _recipientSearch = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (!controller.isGroupMode) ...[
        Text(
          'SELECT A FRIEND',
          style: TextStyle(
            color: context.colors.medium,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        if (controller.loadingFriends)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (controller.friendsLoadFailed)
          Row(children: [
            Expanded(
                child: Text('Unable to refresh friends. Please try again.',
                    style: TextStyle(color: context.colors.medium))),
            TextButton(
                onPressed: controller.fetchFriends, child: const Text('Retry')),
          ]),
        if (!hasFriends &&
            !controller.loadingFriends &&
            !controller.friendsLoadFailed)
          Text(
            'Add some friends to plan a watch together',
            style: TextStyle(color: context.colors.medium, fontSize: 13),
          ),
        if (hasFriends)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: visibleFriends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final friend = visibleFriends[i].friendUser;
                if (friend == null) return const SizedBox.shrink();
                final isSelected = controller.selectedFriendId == friend.id;
                return RecipientOptionTile(
                  title: friend.displayName,
                  avatar: friend.avatar,
                  profileBadges: friend.profileBadges,
                  avatarColor: avatarColorFromIconColor(friend.iconColor),
                  selected: isSelected,
                  onTap: () => controller.selectFriend(friend.id),
                );
              },
            ),
          ),
      ] else ...[
        Text(
          'SELECT A GROUP',
          style: TextStyle(
            color: context.colors.medium,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        if (controller.loadingGroups)
          const SizedBox(
            height: 44,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (controller.groupsLoadFailed)
          Row(children: [
            const Expanded(
                child: Text("Unable to refresh groups. Please try again.")),
            TextButton(
                onPressed: controller.fetchGroups, child: const Text("Retry"))
          ])
        else if (!hasGroups)
          Text(
            "You're not in any groups yet",
            style: TextStyle(color: context.colors.medium, fontSize: 13),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: visibleGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final group = visibleGroups[i];
                final isSelected = controller.selectedGroupId == group.id;
                return RecipientOptionTile(
                  title: group.name,
                  subtitle: group.abbreviation?.isNotEmpty == true
                      ? group.abbreviation
                      : null,
                  selected: isSelected,
                  group: true,
                  groupModel: group,
                  onTap: () => controller.selectGroup(group.id!),
                );
              },
            ),
          ),
      ],
      const SizedBox(height: 16),
    ]);
  }
}
