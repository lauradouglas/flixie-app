import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'group_service.dart';

class SocialGroupsSnapshot {
  const SocialGroupsSnapshot(
      {required this.confirmed,
      required this.groups,
      required this.pending,
      required this.members,
      required this.notifications});
  final List<Group> confirmed, groups;
  final Map<String, GroupMember> pending;
  final Map<String, List<GroupMember>> members;
  final Map<String, FlixieNotification> notifications;
}

/// Group/invitation projection with at most four membership reads in flight.
class SocialGroupsService {
  const SocialGroupsService();
  Future<List<Group>> groups(String viewer) =>
      GroupService.getUserGroups(viewer);
  Future<List<FlixieNotification>> notifications(String viewer) =>
      NotificationService.getNotifications(viewer);
  Future<List<GroupMember>> members(String group) =>
      GroupService.getGroupMembers(group);
  Future<SocialGroupsSnapshot> load(String viewer,
      {bool Function()? owns}) async {
    final results = await Future.wait<Object>([
      groups(viewer),
      notifications(viewer).catchError((_) => <FlixieNotification>[]),
    ]);
    final confirmed = results[0] as List<Group>;
    final invites = <String, FlixieNotification>{};
    final extra = <Group>[];
    for (final notice in results[1] as List<FlixieNotification>) {
      final id = notice.groupInviteGroupId;
      if (notice.type != FlixieNotification.groupInvite ||
          id == null ||
          notice.action == FlixieNotification.actionAccepted ||
          notice.action == FlixieNotification.actionDeclined) {
        continue;
      }
      invites[id] = notice;
      if (!confirmed.any((g) => g.id == id) && !extra.any((g) => g.id == id)) {
        extra.add(Group(
            id: id,
            name: notice.groupInviteGroupName ?? 'Invited Group',
            ownerId: ''));
      }
    }
    final pending = <String, GroupMember>{
      for (final g in extra)
        g.id!: GroupMember(
            groupId: g.id!,
            memberId: viewer,
            role: 'MEMBER',
            inviteStatus: 'PENDING')
    };
    final memberMap = <String, List<GroupMember>>{};
    final queue = confirmed.where((g) => g.id != null).iterator;
    Future<void> worker() async {
      while ((owns?.call() ?? true) && queue.moveNext()) {
        final group = queue.current;
        final rows =
            await members(group.id!).catchError((_) => <GroupMember>[]);
        if (!(owns?.call() ?? true)) return;
        memberMap[group.id!] = rows;
        for (final row in rows) {
          if (row.memberId == viewer && row.isPending) pending[group.id!] = row;
        }
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    return SocialGroupsSnapshot(
        confirmed: confirmed,
        groups: [...confirmed, ...extra],
        pending: pending,
        members: memberMap,
        notifications: invites);
  }
}
