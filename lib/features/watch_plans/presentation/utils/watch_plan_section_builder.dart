import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/models/watch_request.dart';

class FriendWatchPlanSections {
  const FriendWatchPlanSections({
    required this.needsReply,
    required this.upcoming,
    required this.readyToWrapUp,
    required this.planning,
  });

  final List<WatchRequest> needsReply;
  final List<WatchRequest> upcoming;
  final List<WatchRequest> readyToWrapUp;
  final List<WatchRequest> planning;
}

class WatchPlanSectionBuilder {
  const WatchPlanSectionBuilder._();

  static FriendWatchPlanSections friendSections(
    Iterable<WatchRequest> requests,
    String currentUserId, {
    DateTime? now,
  }) {
    final needsReply = <WatchRequest>[];
    final upcoming = <WatchRequest>[];
    final readyToWrapUp = <WatchRequest>[];
    final planning = <WatchRequest>[];

    for (final request in requests) {
      if (WatchPlanDisplayState.needsAttention(request, currentUserId)) {
        needsReply.add(request);
      } else if (WatchPlanDisplayState.isUpcoming(request, now: now)) {
        upcoming.add(request);
      } else if (WatchPlanDisplayState.isPostWatchDue(request, now: now)) {
        readyToWrapUp.add(request);
      } else {
        planning.add(request);
      }
    }

    return FriendWatchPlanSections(
      needsReply: needsReply,
      upcoming: upcoming,
      readyToWrapUp: readyToWrapUp,
      planning: planning,
    );
  }
}
