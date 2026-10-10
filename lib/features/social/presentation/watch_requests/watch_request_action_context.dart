import 'package:flutter/material.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';
import '../../data/request_service.dart';
import '../controllers/watch_requests_controller.dart';

/// Captures a page/account scope for asynchronous sheets and actions.
class WatchRequestActionContext {
  WatchRequestActionContext({required this.context, required this.controller});
  final BuildContext context;
  final WatchRequestsController controller;
  bool get mounted => context.mounted && controller.owns;
  void replaceRequest(WatchRequest request) {
    if (mounted) controller.replace(request);
  }

  Future<void> runAction(WatchRequest request, FriendWatchPlanAction action,
          Future<void> Function() run) =>
      controller.runAction(request.id, action, run);
  Future<void> refreshRequestState(WatchRequest request, String viewer) async {
    if (!mounted || controller.viewer != viewer) return;
    final revision = controller.revision;
    try {
      final state = await RequestService.getWatchRequestState(
          watchRequestId: request.id, userId: viewer);
      if (mounted && controller.revision == revision) {
        controller.replace(state.request);
      }
    } catch (e) {
      logger.w('Watch Plan state refresh failed: $e');
    }
  }
}
