import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/group_member.dart';
import '../../data/group_service.dart';

class GroupMembersController extends ChangeNotifier {
  GroupMembersController(
      {required this.groupId,
      required this.accountId,
      Future<List<GroupMember>> Function(String)? fetch})
      : _fetch = fetch ?? GroupService.getGroupMembers;

  final String groupId;
  final String? accountId;
  final Future<List<GroupMember>> Function(String) _fetch;
  List<GroupMember> members = const [];
  bool loading = true;
  Object? error;
  bool _disposed = false;
  Future<void>? _pending;
  String? _query;
  bool? _pendingOnly;
  List<GroupMember> _filtered = const [];

  static int _rank(GroupMember m) => m.isOwner
      ? 0
      : m.isAdmin
          ? 1
          : m.isPending
              ? 3
              : 2;

  List<GroupMember> filter(String query, {bool pendingOnly = false}) {
    if (_query == query && _pendingOnly == pendingOnly) return _filtered;
    _query = query;
    _pendingOnly = pendingOnly;
    return _filtered = List.unmodifiable(members.where((m) =>
        (!pendingOnly || m.isPending) &&
        (query.isEmpty ||
            m.displayName.toLowerCase().contains(query) ||
            (m.username?.toLowerCase().contains(query) ?? false))));
  }

  Future<void> load() {
    if (_disposed) return Future.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> reloadAfterMutation() async {
    await _pending;
    await load();
  }

  Future<void> _load() async {
    try {
      final result =
          accountId == null ? <GroupMember>[] : await _fetch(groupId);
      if (_disposed) return;
      members = List.unmodifiable(
          [...result]..sort((a, b) => _rank(a).compareTo(_rank(b))));
      _query = null;
      error = null;
    } catch (e) {
      if (_disposed) return;
      error = e;
    }
    if (_disposed) return;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
