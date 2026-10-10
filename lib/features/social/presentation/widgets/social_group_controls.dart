import 'package:flutter/material.dart';

import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class GroupInviteBanner extends StatelessWidget {
  const GroupInviteBanner({
    super.key,
    required this.group,
    required this.count,
    required this.onView,
  });

  final Group group;
  final int count;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.tabBarBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline_rounded,
              color: context.colors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? "You've been invited to ${group.name}"
                  : 'You have $count group invitations',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.light,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onView,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.primaryText,
              side: BorderSide(
                  color: FlixieColors.primary.withValues(alpha: 0.65)),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class GroupSearchField extends StatelessWidget {
  const GroupSearchField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: context.colors.light, fontSize: 14),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search groups',
        hintStyle: TextStyle(color: context.colors.medium),
        prefixIcon: Icon(Icons.search_rounded, color: context.colors.medium),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.close_rounded, color: context.colors.medium),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: context.colors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlixieColors.primary),
        ),
      ),
    );
  }
}

class NoGroupsCard extends StatelessWidget {
  const NoGroupsCard({
    super.key,
    required this.isSearching,
    required this.onCreateGroup,
  });

  final bool isSearching;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.groups_2_outlined,
            color: FlixieColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSearching
                  ? 'No groups match your search.'
                  : 'Create a group to plan watches with friends.',
              style: TextStyle(color: context.colors.medium, fontSize: 13),
            ),
          ),
          if (!isSearching)
            TextButton(
              onPressed: onCreateGroup,
              child: const Text('Create'),
            ),
        ],
      ),
    );
  }
}

class NoGroupInvitesCard extends StatelessWidget {
  const NoGroupInvitesCard({super.key, required this.onCreateGroup});

  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pending invites',
            style: TextStyle(
              color: context.colors.light,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start a group and invite friends to plan what to watch next.',
            style: TextStyle(color: context.colors.medium, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onCreateGroup,
            icon: const Icon(Icons.add),
            label: const Text('Create group'),
            style: FilledButton.styleFrom(
              foregroundColor: context.colors.light,
              backgroundColor: FlixieColors.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class PendingGroupInviteSummary extends StatelessWidget {
  const PendingGroupInviteSummary({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: context.colors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline_rounded, color: context.colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count group invite${count == 1 ? '' : 's'} waiting',
              style: TextStyle(
                color: context.colors.light,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
