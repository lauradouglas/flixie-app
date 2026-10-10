import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_schedule_sheet.dart';
import 'controllers/watch_composer_controller.dart';
import 'widgets/watch_composer/composer_account_sheet.dart';

/// Navigation, nested sheets and feedback for a single account-bound composer.
class WatchComposerActions {
  WatchComposerActions(this.context, this.controller,
      {required this.onSuccess,
      required this.onError,
      required this.fromMovieMatch});
  final BuildContext context;
  final WatchComposerController controller;
  final VoidCallback onSuccess, onError;
  final bool fromMovieMatch;
  bool get active {
    if (!context.mounted || !controller.active) return false;
    final auth = context.read<AuthProvider?>();
    return auth == null || auth.dbUser?.id == controller.requesterId;
  }

  Future<T?> _sheet<T>(Widget child) => showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .92),
      builder: (_) => ComposerAccountSheet(
          viewer: controller.requesterId,
          child: Material(
              color: context.colors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: child)));
  Future<void> send(String message) async {
    if (!active) return;
    final error = controller.validationError;
    if (error != null) {
      ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(type: FlixieToastType.warning, content: Text(error)));
      return;
    }
    final analytics = context.read<AnalyticsController?>();
    final ComposerSubmission? saved;
    try {
      saved = await controller.send(message);
    } catch (error) {
      logger.e('Failed to send watch request: $error');
      if (active) onError();
      return;
    }
    if (saved == null || !active) return;
    // Tracking cannot turn a confirmed write into a retryable save failure.
    try {
      await analytics?.watchPlanCreated(
          watchPlanId: saved.id,
          contentId: saved.movieId,
          contentType: 'movie',
          planType: saved.group ? 'group' : 'friend',
          participantCount: saved.participantCount,
          source: fromMovieMatch ? 'recommendations' : 'movie_detail');
    } catch (error) {
      logger.w('Watch plan saved; analytics unavailable: $error');
    }
    if (!active) return;
    if (!context.mounted) return;
    Navigator.pop(context);
    onSuccess();
  }

  Future<List<MovieShort>> _search(String query) async {
    final result = await controller.service.searchMovies(query);
    if (!active) return [];
    return result
        .where((m) => !controller.movieChoices.any((c) => c.id == m.id))
        .toList();
  }

  Future<void> addMovieChoice() => _choose(cinema: false);
  Future<void> browseCinemaReleases() => _choose(cinema: true);
  Future<void> _choose({required bool cinema}) async {
    if (!active ||
        controller.isSending ||
        controller.movieChoices.length >= controller.maxMovieChoices) {
      return;
    }
    final region = controller.providers.region;
    final movie = await _sheet<MovieShort>(SingleChildScrollView(
        child: MovieSearchSheet(
            title: cinema ? 'In cinemas near you' : 'Add a movie option',
            initialResultsLabel: cinema ? 'Now playing in $region' : null,
            initialMovies: cinema
                ? () async {
                    final movies =
                        await controller.service.cinemaMovies(region);
                    if (!active) return <MovieShort>[];
                    return movies
                        .where((m) =>
                            !controller.movieChoices.any((c) => c.id == m.id))
                        .toList();
                  }
                : null,
            searchMovies: _search)));
    if (movie != null && active) controller.addMovieChoice(movie);
  }

  Future<void> pickSchedule() async {
    if (!active || controller.isSending) return;
    final date = controller.selectedDate, time = controller.selectedTime;
    final initial = date == null
        ? null
        : controller.scheduleMode == ScheduleMode.dateOnly
            ? encodeWatchPlanDate(date)
            : DateTime(date.year, date.month, date.day, time?.hour ?? 12,
                time?.minute ?? 0);
    final selected = await _sheet<
            ({
              DateTime proposedFor,
              bool dateOnly,
              String? message,
              String? location
            })>(
        WatchPlanScheduleSheet(
            initial: initial, initialDateOnly: time == null));
    if (selected != null && active) {
      controller.setSchedule(selected.proposedFor, selected.dateOnly);
    }
  }
}
