import 'package:flutter/foundation.dart';

import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group_watch_request.dart';

/// App-level, memory-backed watch request cache.
///
/// Requests are prefetched after authentication and refreshed silently when a
/// request screen opens. Existing data stays visible while the network check
/// runs.
class WatchRequestCache extends ChangeNotifier {
  final Map<String, List<GroupWatchRequest>> _byGroup = {};
  final Map<String, Future<List<GroupWatchRequest>>> _inFlight = {};
  String? _userId;

  List<GroupWatchRequest> forGroup(String groupId) =>
      List.unmodifiable(_byGroup[groupId] ?? const <GroupWatchRequest>[]);

  void syncUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _byGroup.clear();
    _inFlight.clear();
    if (userId == null || userId.isEmpty) {
      notifyListeners();
      return;
    }
    _preload(userId);
  }

  Future<void> _preload(String userId) async {
    try {
      final groups = await GroupService.getUserGroups(userId);
      if (_userId != userId) return;
      await Future.wait(
        groups
            .map((group) => group.id)
            .whereType<String>()
            .where((groupId) => groupId.isNotEmpty)
            .map(refreshGroup),
      );
    } catch (error) {
      logger.w('Watch request preload failed: $error');
    }
  }

  Future<List<GroupWatchRequest>> refreshGroup(String groupId) {
    final existing = _inFlight[groupId];
    if (existing != null) return existing;

    final request = _fetchGroup(groupId);
    _inFlight[groupId] = request;
    request.then<void>(
      (_) => _inFlight.remove(groupId),
      onError: (Object _, StackTrace __) => _inFlight.remove(groupId),
    );
    return request;
  }

  Future<List<GroupWatchRequest>> _fetchGroup(String groupId) async {
    final requests = await GroupService.getGroupWatchRequests(groupId);
    if (!_sameRequests(_byGroup[groupId], requests)) {
      _byGroup[groupId] = List.unmodifiable(requests);
      notifyListeners();
    }
    return forGroup(groupId);
  }

  bool _sameRequests(
    List<GroupWatchRequest>? previous,
    List<GroupWatchRequest> next,
  ) {
    if (previous == null || previous.length != next.length) return false;
    for (var index = 0; index < next.length; index++) {
      final before = previous[index];
      final after = next[index];
      if (before.id != after.id ||
          before.status != after.status ||
          before.updatedAt != after.updatedAt ||
          before.currentUserResponse != after.currentUserResponse ||
          before.memberStatuses.length != after.memberStatuses.length) {
        return false;
      }
      for (var memberIndex = 0;
          memberIndex < after.memberStatuses.length;
          memberIndex++) {
        final beforeMember = before.memberStatuses[memberIndex];
        final afterMember = after.memberStatuses[memberIndex];
        if (beforeMember.memberId != afterMember.memberId ||
            beforeMember.status != afterMember.status) {
          return false;
        }
      }
    }
    return true;
  }
}
