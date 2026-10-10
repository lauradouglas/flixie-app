import '../widgets/social_account_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';

import 'watch_request_action_context.dart';

class WatchRequestChoiceFlow extends WatchRequestActionContext {
  WatchRequestChoiceFlow({required super.context, required super.controller});
  Future<bool> saveCandidateChoices(
    WatchRequest request,
    String userId, {
    bool showSuccessToast = true,
  }) async {
    if (!context.mounted || !controller.owns) return false;
    if (request.requesterId != userId &&
        !request.isAccepted &&
        !request.isScheduled) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.warning,
          content: const Text('Accept this Watch Plan before choosing movies.'),
          backgroundColor: context.colors.warning,
        ),
      );
      return false;
    }
    var saved = false;
    final candidateIds = controller.draft(request, userId).toList();
    await runAction(request, FriendWatchPlanAction.savingMovieChoices,
        () async {
      try {
        final state = await RequestService.submitWatchPlanChoices(
          watchRequestId: request.id,
          userId: userId,
          candidateIds: candidateIds,
        );
        controller.clearDraft(request.id);
        replaceRequest(state.request);
        saved = true;
        if (!context.mounted || !controller.owns) return;
        if (showSuccessToast) {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
              type: FlixieToastType.success,
              content: const Text('Movie choices saved'),
              backgroundColor: context.colors.surfaceElevated,
            ),
          );
        }
      } catch (_) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Couldn’t save your picks'),
            action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  if (context.mounted &&
                      controller.owns &&
                      !controller.busy(request.id)) {
                    saveCandidateChoices(
                        controller.requests
                                .where((r) => r.id == request.id)
                                .firstOrNull ??
                            request,
                        userId);
                  }
                }),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    });
    return saved;
  }

  Future<void> addCandidate(WatchRequest request, String userId) async {
    if (!context.mounted || !controller.owns) return;
    if (request.candidates.where((c) => c.addedByUserId == userId).length >=
        3) {
      return;
    }
    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      backgroundColor: context.colors.surface,
      builder: (_) => SocialAccountSheet(
          viewer: controller.viewer,
          child: MovieSearchSheet(
            title: 'Add another option',
            searchMovies: (query) async {
              final search = await SearchService.search(query, type: 'movie');
              final existingMovieIds = request.candidates
                  .map((candidate) => candidate.movieId)
                  .whereType<int>()
                  .toSet();
              return search.results
                  .where((item) => item.movie != null)
                  .map((item) => item.movie!)
                  .where((movie) => !existingMovieIds.contains(movie.id))
                  .toList(growable: false);
            },
          )),
    );
    if (!context.mounted || !controller.owns || movie == null) return;
    await runAction(request, FriendWatchPlanAction.scheduling, () async {
      final state = await RequestService.addWatchPlanCandidate(
        watchRequestId: request.id,
        userId: userId,
        movieId: movie.id,
      );
      controller.clearDraft(request.id);
      replaceRequest(state.request);
    });
  }

  Future<void> removeCandidate(
    WatchRequest request,
    String userId,
    String candidateId,
  ) async {
    if (!context.mounted || !controller.owns) return;
    await runAction(request, FriendWatchPlanAction.removingCandidate, () async {
      try {
        final state = await RequestService.removeWatchPlanCandidate(
          watchRequestId: request.id,
          userId: userId,
          candidateId: candidateId,
        );
        controller.clearDraft(request.id);
        replaceRequest(state.request);
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.success,
          content: const Text('Movie option removed'),
          backgroundColor: context.colors.surfaceElevated,
        ));
      } catch (_) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Could not remove that movie option.'),
          backgroundColor: context.colors.danger,
        ));
      }
    });
  }

  Future<void> selectFinalCandidate(
    WatchRequest request,
    String candidateId,
  ) async {
    if (!context.mounted || !controller.owns) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    final candidate =
        request.candidates.where((item) => item.id == candidateId).firstOrNull;
    if (candidate == null) return;
    await runAction(request, FriendWatchPlanAction.selectingMovie, () async {
      try {
        final state = await RequestService.selectWatchPlanCandidate(
          watchRequestId: request.id,
          userId: userId,
          candidateId: candidateId,
        );
        replaceRequest(state.request);
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text(state.request.selectedCandidateId != null
                ? '${candidate.title ?? 'Movie'} finalised'
                : 'Suggested ${candidate.title ?? 'movie'} — waiting for your friend'),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
      } catch (_) {
        if (!context.mounted || !controller.owns) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content:
                const Text('Could not choose this movie. Please try again.'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    });
  }

  Future<void> reopenMovieChoices(WatchRequest request, String userId) async {
    if (!context.mounted || !controller.owns) return;
    await runAction(request, FriendWatchPlanAction.selectingMovie, () async {
      try {
        final state = await RequestService.reopenWatchPlanMovieChoices(
          watchRequestId: request.id,
          userId: userId,
        );
        replaceRequest(state.request);
        if (context.mounted && controller.owns) {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
                type: FlixieToastType.success,
                content: const Text('Movie choices reopened')),
          );
        }
      } catch (_) {
        if (context.mounted && controller.owns) {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not reopen movie choices.'),
              backgroundColor: context.colors.danger,
            ),
          );
        }
      }
    });
  }
}
