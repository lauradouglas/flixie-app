import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/notification.dart';
import '../../data/social_groups_service.dart';

class SocialGroupsController extends ChangeNotifier {
  SocialGroupsController(
      {required this.auth, this.service = const SocialGroupsService()})
      : viewer = auth.dbUser?.id {
    groups = List.of(auth.cachedGroups ?? []);
    loading = groups.isEmpty && viewer != null;
  }
  final AuthProvider auth;
  final SocialGroupsService service;
  final String? viewer;
  List<Group> groups = [];
  Map<String, GroupMember> pendingInvites = {};
  Map<String, List<GroupMember>> groupMembers = {};
  Map<String, FlixieNotification> inviteNotifications = {};
  Map<String, int> memberCounts = {};
  bool loading = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  bool get owns => !_disposed && auth.dbUser?.id == viewer;
  Future<void> load() async {
    if (!owns || viewer == null) return;
    final generation = ++_generation;
    bool current() => owns && generation == _generation;
    try {
      final result = await service.load(viewer!, owns: current);
      if (!current()) return;
      groups = result.groups;
      pendingInvites = result.pending;
      groupMembers = result.members;
      inviteNotifications = result.notifications;
      memberCounts = {
        for (final e in groupMembers.entries)
          e.key: e.value.where((m) => m.isAccepted).length
      };
      error = null;
      auth.updateCachedGroups(result.confirmed);
    } catch (_) {
      if (current()) error = groups.isEmpty ? 'Failed to load groups.' : null;
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void addCreated(Group group) {
    if (!owns) return;
    _generation++;
    groups = [...groups, group];
    loading = false;
    auth.updateCachedGroups(groups);
    notifyListeners();
  }

  void resolveInvite(String id, {required bool accepted}) {
    if (!owns) return;
    _generation++;
    pendingInvites.remove(id);
    inviteNotifications.remove(id);
    if (!accepted) groups.removeWhere((g) => g.id == id);
    loading = false;
    auth.updateCachedGroups(
        groups.where((g) => !pendingInvites.containsKey(g.id)).toList());
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
