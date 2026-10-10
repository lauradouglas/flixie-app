import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

Future<String?> showGroupDetailOptions(BuildContext context,
    {required bool isOwner}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints:
        BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) => SafeArea(
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
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.people_outline, color: context.colors.light),
            title:
                Text('Members', style: TextStyle(color: context.colors.light)),
            onTap: () => Navigator.pop(modalContext, 'members'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline, color: context.colors.light),
            title: Text('Group Info',
                style: TextStyle(color: context.colors.light)),
            onTap: () => Navigator.pop(modalContext),
          ),
          if (isOwner)
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.colors.danger),
              title: Text('Delete Group',
                  style: TextStyle(color: context.colors.danger)),
              onTap: () => Navigator.pop(modalContext, 'delete'),
            ),
        ],
      ),
    )),
  );
}
