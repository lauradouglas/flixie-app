import 'package:flutter/material.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

void showGroupMemberActions(BuildContext context,
    {required GroupMember member,
    required String? currentUserId,
    required bool isOwner,
    required bool isAdmin,
    required void Function(String) changeRole,
    required VoidCallback transfer,
    required VoidCallback remove}) {
  if (member.memberId == currentUserId) return;
  final canPromote = (isOwner || isAdmin) && member.role == 'MEMBER';
  final canDemote =
      (isOwner || isAdmin) && member.role == 'ADMIN' && !member.isOwner;
  final canTransfer = isOwner && member.isAdmin;
  // Owner can remove anyone non-owner; admin can remove plain members
  final canRemove = isOwner || (isAdmin && member.role == 'MEMBER');

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.medium.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              member.displayName,
              style: TextStyle(
                color: context.colors.light,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (canPromote)
            ListTile(
              leading:
                  const Icon(Icons.arrow_upward, color: FlixieColors.primary),
              title: Text('Promote to Admin',
                  style: TextStyle(color: context.colors.light)),
              onTap: () {
                Navigator.pop(sheetContext);
                changeRole('ADMIN');
              },
            ),
          if (canDemote)
            ListTile(
              leading:
                  Icon(Icons.arrow_downward, color: context.colors.warning),
              title: Text('Demote to Member',
                  style: TextStyle(color: context.colors.light)),
              onTap: () {
                Navigator.pop(sheetContext);
                changeRole('MEMBER');
              },
            ),
          if (canTransfer)
            ListTile(
              leading: Icon(Icons.swap_horiz, color: context.colors.secondary),
              title: Text('Transfer Ownership',
                  style: TextStyle(color: context.colors.light)),
              onTap: () {
                Navigator.pop(sheetContext);
                transfer();
              },
            ),
          if (canRemove)
            ListTile(
              leading: Icon(Icons.person_remove_outlined,
                  color: context.colors.danger),
              title: Text('Remove from Group',
                  style: TextStyle(color: context.colors.danger)),
              onTap: () {
                Navigator.pop(sheetContext);
                remove();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    )),
  );
}
