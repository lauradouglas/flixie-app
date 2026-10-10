import 'package:flutter/material.dart';
import 'package:flixie_app/models/notification.dart';

void showNotificationOptions(
  BuildContext context,
  FlixieNotification notification, {
  required void Function(bool) onRead,
  required VoidCallback onDismiss,
  required bool Function() isCurrent,
}) {
  showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .6),
            child: SingleChildScrollView(
                child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notification options',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            ListTile(
                                leading: const Icon(
                                    Icons.mark_email_unread_outlined),
                                title: Text(notification.isRead
                                    ? 'Mark as unread'
                                    : 'Mark as read'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  if (isCurrent()) onRead(!notification.isRead);
                                }),
                            ListTile(
                                leading: const Icon(Icons.delete_outline),
                                title: const Text('Remove notification'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  if (isCurrent()) onDismiss();
                                }),
                          ]),
                    ))),
          ));
}
