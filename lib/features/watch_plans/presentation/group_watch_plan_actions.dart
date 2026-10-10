import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'widgets/group_plan/group_plan_account_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'controllers/group_watch_plan_controller.dart';
import 'sheets/watch_plan_schedule_sheet.dart';
import 'widgets/group_plan/group_plan_components.dart';

/// Route-bound sheets and persisted-action feedback. Every callback captures its account epoch.
class GroupWatchPlanActions {
  GroupWatchPlanActions(this.context, this.controller, {this.groupId})
      : _epoch = controller.epoch,
        _userId = controller.userId;
  final BuildContext context;
  final GroupWatchPlanController controller;
  final String? groupId;
  final int _epoch;
  final String _userId;
  bool get active =>
      context.mounted &&
      controller.isCurrent(_epoch) &&
      context.read<AuthProvider>().dbUser?.id == _userId;
  bool get processing => controller.processing;
  void _ensureActive() {
    if (!active) throw StateError('This Watch Plan session has changed.');
  }

  Future<void> _reload() async {
    if (active) await controller.load();
  }

  Future<void> create() async {
    if (!active) return;
    await _sheet<void>(
      backgroundColor: context.colors.surface,
      builder: (_) => MovieWatchRequestSheet(
        movieId: null,
        movieTitle: null,
        requesterId: _userId,
        friends: const [],
        initialGroupId: groupId,
        onSuccess: _reload,
        onError: () => _showError('Couldn’t create the Watch Plan.'),
      ),
    );
  }

  Future<void> respond(
    GroupWatchRequest request,
    WatchResponseDecision decision,
  ) async {
    await _run(
      () async {
        final conversationId = request.conversationId;
        if (conversationId != null && conversationId.isNotEmpty) {
          await GroupService.respondToWatchRequest(
            conversationId,
            request.id,
            _userId,
            decision,
          );
        } else {
          await GroupService.updateWatchRequestForMember(
            _requestId(request),
            _userId,
            '',
            decision.apiValue,
          );
        }
      },
      success: decision == WatchResponseDecision.accepted
          ? 'You joined the Watch Plan.'
          : 'You left this screening.',
    );
  }

  Future<void> saveChoices(
    GroupWatchRequest request,
    Set<String> choices,
  ) async {
    if (choices.isEmpty) {
      _showError('Choose at least one movie you would watch.');
      return;
    }
    await _run(() async {
      await GroupService.saveWatchPlanChoices(
        _requestId(request),
        _userId,
        choices.toList(),
      );
      if (active) controller.clearDraft(request.id);
    }, success: 'Your movie picks are saved.');
  }

  Future<void> reopenChoices(GroupWatchRequest request) async {
    await _run(() async {
      await GroupService.reopenWatchPlanMovieSelection(
        _requestId(request),
        _userId,
      );
      if (active) controller.clearDraft(request.id);
    });
  }

  Future<void> addCandidate(GroupWatchRequest request) async {
    if (!active) return;
    final movie = await _sheet<MovieShort>(
      backgroundColor: context.colors.surface,
      builder: (_) => MovieSearchSheet(
        title: 'Add a movie option',
        searchMovies: (query) async {
          final result = await SearchService.search(query, type: 'movie');
          final existing =
              request.candidates.map((item) => item.movieId).toSet();
          return result.results
              .map((item) => item.movie)
              .whereType<MovieShort>()
              .where((item) => !existing.contains(item.id))
              .toList(growable: false);
        },
      ),
    );
    if (!active || movie == null) return;
    await _run(() async {
      final updated = await GroupService.addWatchPlanCandidate(
        _requestId(request),
        _userId,
        movie.id,
      );
      final newOptions = updated.candidates.where(
        (candidate) =>
            candidate.movieId == movie.id &&
            candidate.addedByUserId == _userId &&
            candidate.selectedByUserIds.contains(_userId),
      );
      if (active) {
        controller.addChoices(
          request,
          newOptions.map((candidate) => candidate.id),
        );
      }
    }, success: '${movie.name} was added.');
  }

  Future<void> chooseMovie(GroupWatchRequest request, String id) async {
    await _run(() async {
      await GroupService.selectWatchPlanMovie(_requestId(request), _userId, id);
    }, success: 'The final movie is set.');
  }

  Future<void> propose(GroupWatchRequest request, {String? initialIso}) async {
    if (!active) return;
    final result = await _sheet<
        ({
          DateTime proposedFor,
          bool dateOnly,
          String? message,
          String? location,
        })>(
      backgroundColor: Colors.transparent,
      builder: (_) => WatchPlanScheduleSheet(
        initial: DateTime.tryParse(initialIso ?? ''),
        initialDateOnly: initialIso == null ||
            (initialIso == request.scheduledFor
                ? request.scheduledDateOnly
                : request.activeScheduleProposal?.dateOnly ??
                    request.proposedDateOnly),
        initialLocation: request.location,
        showLocation: true,
      ),
    );
    if (!active || result == null) return;
    await _run(() async {
      await GroupService.proposeWatchPlanSchedule(
        _requestId(request),
        _userId,
        proposedFor: result.proposedFor.toUtc().toIso8601String(),
        dateOnly: result.dateOnly,
        location: result.location,
      );
    }, success: 'The new schedule was sent to the group.');
  }

  Future<void> approveTime(GroupWatchRequest request) async {
    final proposal = request.activeScheduleProposal;
    final iso = proposal?.proposedFor ?? request.proposedDate;
    final time = DateTime.tryParse(iso ?? '')?.toLocal();
    if (time == null ||
        watchPlanScheduleHasPassed(
          time,
          dateOnly: proposal?.dateOnly ?? request.proposedDateOnly,
        )) {
      _showError('That proposed time has passed. Suggest a new time.');
      return;
    }
    await _run(
      () async {
        if (proposal == null) {
          await GroupService.acceptInitialWatchPlanSchedule(
            _requestId(request),
            _userId,
          );
        } else {
          await GroupService.respondToWatchPlanSchedule(
            _requestId(request),
            proposal.id,
            _userId,
            'accepted',
          );
        }
      },
      success:
          'You approved ${formatGroupPlanTime(context, iso, dateOnly: proposal?.dateOnly ?? request.proposedDateOnly)}.',
    );
  }

  Future<void> declineTime(GroupWatchRequest request) async {
    if (request.activeScheduleProposal != null &&
        request.scheduledFor?.isNotEmpty == true) {
      await keepCurrentTime(request);
      return;
    }
    await respond(request, WatchResponseDecision.declined);
  }

  Future<void> keepCurrentTime(GroupWatchRequest request) async {
    final proposal = request.activeScheduleProposal;
    if (proposal == null) return;
    if (request.userId == _userId) {
      await finalizeReplacement(request, proposal, false);
      return;
    }
    await _run(() async {
      await GroupService.respondToWatchPlanSchedule(
        _requestId(request),
        proposal.id,
        _userId,
        'declined',
      );
    }, success: 'The current time stays confirmed.');
  }

  Future<void> finalizeReplacement(
    GroupWatchRequest request,
    GroupScheduleProposal proposal,
    bool acceptNew,
  ) async {
    await _run(
      () async {
        await GroupService.finalizeWatchPlanSchedule(
          _requestId(request),
          proposal.id,
          _userId,
          acceptNew ? 'accept_new' : 'keep_current',
        );
      },
      success: acceptNew
          ? 'The new time is confirmed.'
          : 'The current time stays confirmed.',
    );
  }

  Future<void> logWatch(GroupWatchRequest request) async {
    if (!active) return;
    await _sheet<void>(
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        showReviewOption: false,
        isPlanReview: true,
        onSubmit: ({
          required watchedAt,
          required rating,
          required recommended,
          required notes,
        }) async {
          _ensureActive();
          final saved = await controller.run(() async {
            await GroupService.logGroupWatchPlan(
              request,
              _userId,
              watchedAt: watchedAt,
              rating: rating?.round(),
              recommended: recommended,
              reviewText: notes,
            );
          });
          if (!saved) {
            throw StateError('This Watch Plan session has changed.');
          }
        },
      ),
    );
  }

  Future<void> missed(GroupWatchRequest request) async {
    await _run(() async {
      await GroupService.logGroupWatchPlan(request, _userId, watched: false);
    }, success: 'Marked as missed. No watch entry, rating, or review added.');
  }

  String _requestId(GroupWatchRequest request) =>
      request.databaseRequestId ?? request.id;

  String _friendlyError(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '').trim();
    return value.isEmpty ? 'That action couldn’t be completed.' : value;
  }

  void _showError(String message) => !active
      ? null
      : ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: Text(message),
            backgroundColor: context.colors.danger,
          ),
        );

  void _showSuccess(String message) => !active
      ? null
      : ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            backgroundColor: context.colors.surfaceElevated,
            content: Text(message),
          ),
        );

  Future<T?> _sheet<T>({
    required WidgetBuilder builder,
    Color? backgroundColor,
  }) {
    if (!active) return Future.value();
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (sheetContext) =>
          GroupPlanAccountSheet(viewer: _userId, child: builder(sheetContext)),
    );
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (!active || processing) return;
    try {
      final saved = await controller.run(() async {
        _ensureActive();
        await action();
        if (active) {
          TabRefreshController.requestSocialRefresh();
          TabRefreshController.requestHomeRefresh();
        }
      });
      if (saved && active && success != null) _showSuccess(success);
    } catch (error) {
      if (active) _showError(_friendlyError(error));
    }
  }
}
