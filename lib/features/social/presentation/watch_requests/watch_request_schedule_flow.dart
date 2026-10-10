import '../widgets/social_account_sheet.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_formatters.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_schedule_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';

import 'watch_request_action_context.dart';
import 'watch_request_actions.dart';
import '../widgets/watch_requests/watch_plan_calendar_sheet.dart';

class WatchRequestScheduleFlow extends WatchRequestActionContext {
  WatchRequestScheduleFlow(
      {required super.context,
      required super.controller,
      required this.actions});
  final WatchRequestActions actions;
  Future<void> suggestSchedule(WatchRequest request,
      {DateTime? initial}) async {
    if (!context.mounted || !controller.owns) return;
    final selected = await _showScheduleProposalSheet(
      initial: initial,
      initialDateOnly: initial == null || request.scheduledDateOnly,
      initialLocation: request.location,
    );
    if (!context.mounted || !controller.owns || selected == null) return;
    if (request.isPending &&
        !await actions.respond(request, 'ACCEPTED',
            acceptProposedTime: false)) {
      return;
    }
    if (!context.mounted || !controller.owns) return;
    await submitScheduleProposal(
      request,
      FriendAcceptanceScheduleDraft(
        proposedFor: selected.proposedFor,
        dateOnly: selected.dateOnly,
        message: selected.message,
        location: selected.location,
      ),
    );
  }

  Future<
          ({
            DateTime proposedFor,
            bool dateOnly,
            String? message,
            String? location
          })?>
      _showScheduleProposalSheet(
          {DateTime? initial,
          String? initialLocation,
          bool initialDateOnly = true}) {
    return showModalBottomSheet<
        ({
          DateTime proposedFor,
          bool dateOnly,
          String? message,
          String? location
        })>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      backgroundColor: Colors.transparent,
      builder: (_) => SocialAccountSheet(
          viewer: controller.viewer,
          child: WatchPlanScheduleSheet(
            initial: initial,
            initialDateOnly: initialDateOnly,
            initialLocation: initialLocation,
          )),
    );
  }

  Future<void> submitScheduleProposal(
    WatchRequest request,
    FriendAcceptanceScheduleDraft selected,
  ) async {
    if (!context.mounted || !controller.owns) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;

    await runAction(request, FriendWatchPlanAction.scheduling, () async {
      try {
        final state = await RequestService.proposeWatchSchedule(
          watchRequestId: request.id,
          userId: userId,
          proposedFor: selected.proposedFor,
          dateOnly: selected.dateOnly,
          message: selected.message,
          location: selected.location,
        );
        if (!context.mounted || !controller.owns) return;
        replaceRequest(state.request);
        await refreshRequestState(state.request, userId);
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.info,
            content: Text(request.scheduledFor == null
                ? 'Suggested ${formatWatchPlanDateTime(selected.proposedFor, dateOnly: selected.dateOnly)}'
                : 'New time proposed - the current plan stays in place until they agree'),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
      } catch (e) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Failed to schedule watch. Please try again.'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    });
  }

  Future<void> respondToProposal(
    WatchRequest request,
    WatchScheduleProposal proposal,
    String decision,
  ) async {
    if (!context.mounted || !controller.owns) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    final analytics = context.read<AnalyticsController>();
    if (userId == null || userId.isEmpty) return;
    if (decision == 'accepted' &&
        proposal.proposedFor != null &&
        watchPlanScheduleHasPassed(proposal.proposedFor!,
            dateOnly: proposal.dateOnly)) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.warning,
          content:
              const Text('That proposed time has passed. Suggest a new time.'),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }

    await runAction(request, FriendWatchPlanAction.scheduling, () async {
      try {
        final state = await RequestService.respondToWatchScheduleProposal(
          watchRequestId: request.id,
          proposalId: proposal.id,
          userId: userId,
          decision: decision,
        );
        if (!context.mounted || !controller.owns) return;
        replaceRequest(state.request);
        await refreshRequestState(state.request, userId);
        if (!context.mounted || !controller.owns) return;
        final agreedTime = state.request.scheduledFor ?? proposal.proposedFor;
        if (decision == 'accepted' && agreedTime != null) {
          await analytics.watchPlanScheduled(
            watchPlanId: state.request.id,
            contentId: state.request.analyticsContentId,
            contentType: state.request.analyticsContentType,
            planType: state.request.analyticsPlanType,
            participantCount: state.request.analyticsParticipantCount,
            source: 'watch_plan',
          );
          await PushNotificationService.scheduleWatchPlanReminders(
            planId: state.request.id,
            scheduledFor: agreedTime,
            dateOnly: state.request.scheduledDateOnly,
            title: state.request.watchPlanTitle,
            withName: state.request.participants
                    .map((participant) => participant.user)
                    .whereType<WatchRequestUser>()
                    .where((participant) => participant.id != userId)
                    .firstOrNull
                    ?.username ??
                'your friend',
            deepLink: '/watch-requests/${state.request.id}',
          );
        }
        if (!context.mounted || !controller.owns) return;
        if (decision == 'accepted' && agreedTime != null) {
          final addToCalendar = await showWatchPlanCalendarSheet(
                context: context,
                controller: controller,
                title: state.request.movie?.title ?? 'Watch together',
                scheduledFor: agreedTime,
                dateOnly: state.request.scheduledDateOnly,
                posterPath: state.request.movie?.posterPath,
              ) ??
              false;
          if (!context.mounted || !controller.owns) return;
          if (addToCalendar) {
            await WatchCalendarService.addScheduledWatch(
              title: state.request.movie?.title ?? 'Watch together',
              scheduledFor: agreedTime,
              dateOnly: state.request.scheduledDateOnly,
              runtimeMinutes: state.request.movie?.runtimeMinutes,
              note: state.request.message,
              location: state.request.location,
            );
          }
        }
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text(decision == 'accepted'
                ? state.request.scheduledDateOnly
                    ? 'Watch date agreed'
                    : 'Watch time agreed'
                : request.scheduledFor != null
                    ? 'New time declined - your original plan is unchanged'
                    : 'Time declined'),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
      } catch (e) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content:
                const Text('Failed to update proposed time. Please try again.'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    });
  }
}
