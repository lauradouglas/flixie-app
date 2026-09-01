import 'package:flutter/foundation.dart';

import 'package:flixie_app/models/group_watch_request.dart';

enum GroupWatchPlanFilter { all, needsResponse, active, completed, byMe }

class GroupWatchPlanController extends ChangeNotifier {
  GroupWatchPlanController({
    required this.currentUserId,
    List<GroupWatchRequest> initialRequests = const [],
  }) : requests = List.of(initialRequests);

  final String currentUserId;
  List<GroupWatchRequest> requests;
  bool loading = false;
  String searchQuery = '';
  GroupWatchPlanFilter filter = GroupWatchPlanFilter.active;
  final Map<String, bool> processing = {};
  final Map<String, String> processingResponses = {};
  final Map<String, String> myResponses = {};
  final Map<String, Set<String>> candidateChoiceDrafts = {};

  int get activeCount => requests.where((request) => request.isActive).length;
  int get completedCount => requests
      .where((request) => request.status == WatchRequestStatus.completed)
      .length;
  int get needsResponseCount => requests.where(needsResponse).length;

  bool hasResponded(GroupWatchRequest request) {
    if (myResponses[request.id] != null ||
        request.currentUserResponse != null) {
      return true;
    }
    return request.memberStatuses.any(
      (member) =>
          member.memberId == currentUserId &&
          const {'ACCEPTED', 'DECLINED', 'MAYBE'}.contains(member.status),
    );
  }

  bool needsResponse(GroupWatchRequest request) =>
      request.canRespond &&
      request.userId != currentUserId &&
      !hasResponded(request);

  void setRequests(List<GroupWatchRequest> value) {
    requests = List.of(value);
    notifyListeners();
  }

  void setLoading(bool value) {
    if (loading == value) return;
    loading = value;
    notifyListeners();
  }

  void setFilter(GroupWatchPlanFilter value) {
    if (filter == value) return;
    filter = value;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    notifyListeners();
  }

  void replaceRequest(GroupWatchRequest updated) {
    requests = requests
        .map((request) => request.matchesId(updated.id) ? updated : request)
        .toList(growable: false);
    notifyListeners();
  }

  List<GroupWatchRequest> filtered({String? focusedId}) {
    var list = requests;
    if (focusedId?.isNotEmpty == true) {
      return _sort(list.where((request) => request.matchesId(focusedId!)));
    }
    switch (filter) {
      case GroupWatchPlanFilter.active:
        list = list.where((request) => request.isActive).toList();
      case GroupWatchPlanFilter.needsResponse:
        list = list.where(needsResponse).toList();
      case GroupWatchPlanFilter.completed:
        list = list
            .where((request) => request.status == WatchRequestStatus.completed)
            .toList();
      case GroupWatchPlanFilter.byMe:
        list =
            list.where((request) => request.userId == currentUserId).toList();
      case GroupWatchPlanFilter.all:
        break;
    }
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((request) {
        return (request.movieTitle ?? '').toLowerCase().contains(query) ||
            (request.requesterUsername ?? '').toLowerCase().contains(query) ||
            (request.message ?? '').toLowerCase().contains(query);
      }).toList();
    }
    return _sort(list);
  }

  List<GroupWatchRequest> _sort(Iterable<GroupWatchRequest> values) {
    final sorted = values.toList();
    sorted.sort((a, b) {
      if (filter == GroupWatchPlanFilter.completed) {
        return _date(b.completedAt ?? b.updatedAt ?? b.createdAt)
            .compareTo(_date(a.completedAt ?? a.updatedAt ?? a.createdAt));
      }
      if (filter == GroupWatchPlanFilter.active ||
          filter == GroupWatchPlanFilter.needsResponse) {
        final aDate = _date(a.scheduledFor ?? a.proposedDate);
        final bDate = _date(b.scheduledFor ?? b.proposedDate);
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        if (aDate != epoch && bDate != epoch) return aDate.compareTo(bDate);
        if (aDate != epoch) return -1;
        if (bDate != epoch) return 1;
      }
      return _date(b.lastActivityAt ?? b.updatedAt ?? b.createdAt)
          .compareTo(_date(a.lastActivityAt ?? a.updatedAt ?? a.createdAt));
    });
    return sorted;
  }

  DateTime _date(String? iso) =>
      DateTime.tryParse(iso ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
}
