import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';

/// Existing group reads and local reminder cleanup, replaceable in focused tests.
class GroupWatchPlanService {
  const GroupWatchPlanService();
  Future<List<Group>> groups(String userId) =>
      GroupService.getUserGroups(userId);
  Future<List<GroupWatchRequest>> plans(String groupId, String scope) =>
      GroupService.getGroupWatchRequests(groupId, requestScope: scope);
  Future<List<GroupMember>> members(String groupId) =>
      GroupService.getGroupMembers(groupId);
  Future<void> cancelReminders(String id) =>
      PushNotificationService.cancelWatchPlanReminders(id, scope: 'GROUP');
}
