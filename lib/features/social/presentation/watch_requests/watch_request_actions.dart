import '../widgets/social_account_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';

import 'watch_request_action_context.dart';

class WatchRequestActions extends WatchRequestActionContext {
  WatchRequestActions(
      {required super.context,
      required super.controller,
      required this.groupMode,
      required this.onGroupCreated});
  final bool groupMode;
  final VoidCallback onGroupCreated;
  Future<void> startNewWatchPlan({String? initialFriendId}) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null || userId.isEmpty) return;

    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SocialAccountSheet(
          viewer: controller.viewer,
          child: MovieSearchSheet(
            title: 'Choose a movie',
            searchMovies: (query) async {
              final search = await SearchService.search(query, type: 'movie');
              return search.results
                  .where((item) => item.movie != null)
                  .map((item) => item.movie!)
                  .toList(growable: false);
            },
          )),
    );
    if (!context.mounted ||
        !controller.owns ||
        controller.viewer != userId ||
        movie == null) {
      return;
    }

    final creatingGroupPlan = groupMode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocialAccountSheet(
          viewer: controller.viewer,
          child: MovieWatchRequestSheet(
            movieId: movie.id,
            movieTitle: movie.name,
            moviePoster: movie.poster,
            requesterId: userId,
            friends: auth.cachedFriends?.friendships ?? const [],
            initialGroupMode: creatingGroupPlan,
            initialFriendId: initialFriendId,
            onSuccess: () {
              if (!context.mounted || !controller.owns) return;
              if (creatingGroupPlan) {
                onGroupCreated();
                controller.loadGroups();
              }
              // Group plans are rendered by a separate overview with its own
              // data source. Notify it immediately after creation as well as
              // refreshing the direct-plan list.
              TabRefreshController.requestSocialRefresh();
              TabRefreshController.requestHomeRefresh();
              ScaffoldMessenger.of(context).showFlixieToast(
                FlixieToast(
                  type: FlixieToastType.success,
                  content: const Text('Watch Plan sent'),
                  backgroundColor: context.colors.surfaceElevated,
                ),
              );
            },
            onError: () {
              if (!context.mounted || !controller.owns) return;
              ScaffoldMessenger.of(context).showFlixieToast(
                FlixieToast(
                  type: FlixieToastType.error,
                  content: const Text('Could not send the Watch Plan'),
                  backgroundColor: context.colors.danger,
                ),
              );
            },
          )),
    );
  }

  Future<void> confirmDelete(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final isCreator = request.requesterId == userId;
    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => SocialAccountSheet(
          viewer: controller.viewer,
          child: FlixiePromptSheetContent(
            title: Text(isCreator ? 'Close Watch Plan?' : 'Leave Watch Plan?'),
            content: const Text(
              'This permanently closes the shared plan, its schedule and related notifications for everyone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep plan'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.danger,
                  foregroundColor: Colors.white,
                ),
                child:
                    Text(isCreator ? 'Close for everyone' : 'Leave and close'),
              ),
            ],
          )),
    );
    if (confirmed != true || !context.mounted || !controller.owns) return;

    await runAction(request, FriendWatchPlanAction.deleting, () async {
      try {
        await RequestService.deleteWatchRequest(
          watchRequestId: request.id,
          userId: userId,
        );
        if (!context.mounted || !controller.owns) return;
        controller.remove(request.id);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.info,
              content: const Text('Watch Plan closed')),
        );
        if (controller.focusedId?.isNotEmpty == true) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/watch-requests');
          }
        }
      } catch (e) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Could not delete the Watch Plan'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    });
  }

  Future<void> closeWatchPlan(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => SocialAccountSheet(
          viewer: controller.viewer,
          child: FlixiePromptSheetContent(
            title: const Text('Can’t make it?'),
            content: const Text(
              'This removes the Watch Plan from your list. It stays scheduled for everyone else.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep plan'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('I can’t make it'),
              ),
            ],
          )),
    );
    if (confirmed != true || !context.mounted || !controller.owns) return;

    await controller.close(request.id);
    if (!context.mounted || !controller.owns) return;
    ScaffoldMessenger.of(context).showFlixieToast(
      FlixieToast(
          type: FlixieToastType.info,
          content: const Text('You’re no longer attending this plan')),
    );
    if (controller.focusedId?.isNotEmpty == true) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/watch-requests');
      }
    }
  }

  Future<bool> respond(WatchRequest request, String response,
      {bool acceptProposedTime = true}) async {
    final analytics = context.read<AnalyticsController>();
    var succeeded = false;
    final action = switch (response) {
      'ACCEPTED' => FriendWatchPlanAction.accepting,
      'DECLINED' => FriendWatchPlanAction.declining,
      _ => FriendWatchPlanAction.maybe,
    };
    await runAction(request, action, () async {
      try {
        await RequestService.updateRequest(request.id, response,
            acceptProposedTime: acceptProposedTime);
        if (!context.mounted || !controller.owns) return;
        if (response == 'ACCEPTED') {
          await analytics.watchPlanAccepted(
            watchPlanId: request.id,
            contentId: request.analyticsContentId,
            contentType: request.analyticsContentType,
            planType: request.analyticsPlanType,
            participantCount: request.analyticsParticipantCount,
            source: 'watch_plan',
          );
        }
        await controller.load();
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text(_responseSuccessMessage(response)),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
        succeeded = true;
      } catch (e) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: Text(_responseFailureMessage(response)),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    });
    return succeeded;
  }

  Future<void> cancelPlan(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => SocialAccountSheet(
          viewer: controller.viewer,
          child: FlixiePromptSheetContent(
            title: const Text('Cancel this watch plan?'),
            content: const Text(
              'This removes the watch plan and its related notifications for everyone taking part.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep plan'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                    foregroundColor: context.colors.danger),
                child: const Text('Cancel plan'),
              ),
            ],
          )),
    );
    if (confirmed != true || !context.mounted || !controller.owns) return;
    await runAction(request, FriendWatchPlanAction.declining, () async {
      try {
        await RequestService.deleteWatchRequest(
          watchRequestId: request.id,
          userId: userId,
        );
        if (!context.mounted || !controller.owns) return;
        controller.remove(request.id);
        if (context.mounted && controller.owns) {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
                type: FlixieToastType.success,
                content: const Text('Watch plan cancelled for everyone')),
          );
          if (controller.focusedId?.isNotEmpty == true) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/watch-requests');
            }
          }
        }
      } catch (_) {
        if (context.mounted && controller.owns) {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not cancel the watch plan'),
              backgroundColor: context.colors.danger,
            ),
          );
        }
      }
    });
  }

  Future<void> markNotThisTime(WatchRequest request) async {
    if (!context.mounted || !controller.owns) return;
    final userId = controller.viewer;
    if (userId == null || userId.isEmpty) return;
    await runAction(request, FriendWatchPlanAction.completing, () async {
      try {
        final state = await RequestService.confirmWatchRequest(
            watchRequestId: request.id, userId: userId, watched: false);
        if (!context.mounted || !controller.owns) return;
        replaceRequest(state.request);
      } catch (e) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text(
                'Could not update your attendance. Please try again.')));
      }
    });
  }

  String _responseSuccessMessage(String response) {
    return switch (response) {
      'ACCEPTED' => 'Watch Plan accepted.',
      'DECLINED' => 'Watch Plan declined.',
      _ => 'Marked as maybe.',
    };
  }

  String _responseFailureMessage(String response) {
    return switch (response) {
      'ACCEPTED' => 'Failed to accept. Please try again.',
      'DECLINED' => 'Failed to decline. Please try again.',
      _ => 'Failed to mark maybe. Please try again.',
    };
  }
}
