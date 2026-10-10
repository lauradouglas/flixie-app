import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/movie_list.dart';
import '../../data/group_service.dart';
import '../../../profile/data/user_service.dart';

/// One account/group lifetime. Replacing the owner invalidates all old replies.
class GroupDetailController extends ChangeNotifier {
  GroupDetailController(
      {required this.groupId,
      required this.accountId,
      required this.isCurrent,
      required this.fetchRequests,
      this.fetchGroup = GroupService.getGroup,
      this.fetchMembers = GroupService.getGroupMembers,
      this.fetchLists = UserService.getMovieLists});

  final String groupId;
  final String? accountId;
  final bool Function() isCurrent;
  final Future<Group> Function(String) fetchGroup;
  final Future<List<GroupMember>> Function(String) fetchMembers;
  final Future<List<MovieList>> Function(String) fetchLists;
  final Future<List<GroupWatchRequest>> Function(String) fetchRequests;
  Group? group;
  List<GroupMember> members = const [];
  List<MovieList> lists = const [];
  List<GroupWatchRequest> requests = const [];
  bool loading = true, listsLoading = true, listsFailed = false;
  String? error;
  bool _disposed = false;
  Future<void>? _pending;
  bool get current => !_disposed && isCurrent();
  int get memberCount => members.where((member) => member.isAccepted).length;

  Future<void> load() {
    if (!current) return Future.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    if (accountId == null) {
      loading = listsLoading = false;
      error = 'Sign in to view this group.';
      notifyListeners();
      return;
    }
    loading = group == null;
    listsLoading = true;
    listsFailed = false;
    error = null;
    notifyListeners();
    // Start all four reads together, but optional reads cannot block the header.
    await Future.wait([_loadCore(), _loadLists(), _loadRequests()]);
  }

  Future<void> _loadCore() async {
    try {
      final values =
          await Future.wait([fetchGroup(groupId), fetchMembers(groupId)]);
      if (!current) return;
      group = values[0] as Group;
      members = List.unmodifiable(values[1] as List<GroupMember>);
    } catch (e) {
      if (!current) return;
      if (e is ApiException && [401, 403, 404].contains(e.statusCode)) {
        group = null;
        members = const [];
        lists = const [];
        requests = const [];
      }
      error = 'Couldn’t load group. Check your connection.';
    }
    if (!current) return;
    loading = false;
    notifyListeners();
  }

  Future<void> _loadLists() async {
    try {
      final result = await fetchLists(accountId!);
      if (!current) return;
      lists =
          List.unmodifiable(result.where((list) => list.groupId == groupId));
    } catch (_) {
      if (!current) return;
      lists = const [];
      listsFailed = true;
    }
    if (!current) return;
    listsLoading = false;
    notifyListeners();
  }

  Future<void> _loadRequests() async {
    try {
      final result = await fetchRequests(groupId);
      if (!current) return;
      requests = List.unmodifiable(result);
    } catch (_) {
      if (!current) return;
      requests = const [];
    }
    if (current) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
