import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/auth/notification_deep_link.dart';

String notificationDestination(FlixieNotification n) {
  if (n.type == FlixieNotification.communityInvite && n.closed == true) {
    final community = int.tryParse(n.data?['communityId']?.toString() ?? '');
    return n.action == FlixieNotification.actionAccepted &&
            community != null &&
            community <= -1000
        ? '/genre-communities/$community'
        : '/private-communities';
  }
  String? destination;
  if (n.type == FlixieNotification.groupInvite &&
      n.linkedRequestId != null &&
      n.groupInviteGroupId != null) {
    destination =
        '/group-invites/${n.linkedRequestId}?groupId=${n.groupInviteGroupId}';
  } else if (n.isWatchPlanNotification && n.linkedRequestId != null) {
    final groupId = n.groupWatchGroupId;
    destination = groupId != null
        ? '/groups/$groupId?tab=requests&requestId=${n.linkedRequestId}'
        : '/watch-requests/${n.linkedRequestId}${const [
            'COMPANION_LOGGED',
            'COMPANION_RATED'
          ].contains(n.watchPlanEvent) ? '?log=true' : ''}';
  } else {
    destination = notificationDeepLinkPath({
      ...?n.data,
      'type': n.type,
      if (n.route != null) 'route': n.route!,
      if (n.relatedId != null) 'relatedId': n.relatedId!,
      if (n.senderId != null) 'friendId': n.senderId!,
    });
  }
  return destination;
}
