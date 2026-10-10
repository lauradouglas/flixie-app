import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'group_service.dart';
import 'request_service.dart';
import 'watch_plan_visibility_store.dart';

/// Read boundary for direct plans and the Groups badge. Group browsing owns its
/// own detailed snapshots; this projection does not fetch members or messages.
class WatchRequestsService {
  const WatchRequestsService();

  Future<List<WatchRequest>> load(String viewer) =>
      RequestService.getWatchRequests(viewer, includeHomeState: true);
  Future<WatchRequest> focused(String viewer, String id, Object scope) async =>
      (await RequestService.getWatchRequestState(
              watchRequestId: id, userId: viewer, requestScope: scope))
          .request;
  Future<Set<String>> closed(String viewer) =>
      WatchPlanVisibilityStore.closedPlanIds(viewer);
  Future<List<Group>> groups(String viewer) =>
      GroupService.getUserGroups(viewer);
  Future<int> activeCount(List<Group> groups,
      {required bool Function() current}) async {
    final ids = groups
        .map((g) => g.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    var next = 0;
    var count = 0;
    Future<void> worker() async {
      while (current() && next < ids.length) {
        final id = ids[next++];
        final requests = await GroupService.getGroupWatchRequests(id);
        if (!current()) return;
        count += requests.where((r) => r.isActive).length;
      }
    }

    await Future.wait(List.generate(ids.length.clamp(0, 4), (_) => worker()));
    return count;
  }
}
