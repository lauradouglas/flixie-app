import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flutter_test/flutter_test.dart';

const me = WatchRequestUser(id: 'me', username: 'Laura');
const jamie = WatchRequestUser(id: 'jamie', username: 'Jamie');

WatchRequest plan({
  String id = 'plan',
  String requesterId = 'jamie',
  String status = 'accepted',
  String scheduleStatus = 'NONE',
  DateTime? scheduledFor,
  String? location,
  String? selectedCandidateId,
  List<WatchPlanCandidate> candidates = const [],
  List<WatchScheduleProposal> proposals = const [],
  List<WatchConfirmation> confirmations = const [],
  bool? currentUserAccepted = true,
}) =>
    WatchRequest(
      id: id,
      requesterId: requesterId,
      recipientId: 'me',
      status: status,
      type: 'MOVIE_WATCH_REQUEST',
      scheduleStatus: scheduleStatus,
      scheduledFor: scheduledFor,
      location: location,
      selectedCandidateId: selectedCandidateId,
      candidates: candidates,
      scheduleProposals: proposals,
      watchConfirmations: confirmations,
      hasCurrentUserAccepted: currentUserAccepted,
      requester: jamie,
      recipient: me,
      movie: const WatchRequestMovieDetails(id: 1, title: 'Inception'),
    );

WatchPlanCandidate candidate(
  String id, {
  List<String> selectedBy = const [],
}) =>
    WatchPlanCandidate(
      id: id,
      movieId: id.hashCode,
      mediaType: 'movie',
      addedByUserId: 'me',
      title: id,
      selectedByUserIds: selectedBy,
    );

void main() {
  final now = DateTime(2026, 9, 2, 12);

  test('invitation outranks an upcoming plan', () {
    final selected = selectHomeWatchPlanState([
      plan(
          id: 'upcoming',
          scheduledFor: now.add(const Duration(days: 1)),
          location: 'Cinema',
          scheduleStatus: 'AGREED'),
      plan(id: 'invite', status: 'pending', currentUserAccepted: false),
    ], 'me', now: now);

    expect(selected?.plan.id, 'invite');
    expect(selected?.type, HomeWatchPlanStateType.invitation);
    expect(selected?.actionLabel, 'View invitation');
  });

  test('accepted participant is prompted to choose movies', () {
    final selected = selectHomeWatchPlanState([
      plan(candidates: [candidate('one'), candidate('two')]),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.chooseMovies);
    expect(selected?.actionLabel, 'Choose movies');
  });

  test('creator sees final selection after every person has chosen', () {
    final selected = selectHomeWatchPlanState([
      plan(
        requesterId: 'me',
        candidates: [
          candidate('one', selectedBy: ['me']),
          candidate('two', selectedBy: ['me', 'jamie']),
        ],
      ),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.chooseFinalMovie);
    expect(selected?.supportingText, '1 movie works for everyone');
  });

  test('today is stronger than an ordinary upcoming plan', () {
    final selected = selectHomeWatchPlanState([
      plan(
          id: 'later',
          scheduledFor: now.add(const Duration(days: 2)),
          location: 'Home',
          scheduleStatus: 'AGREED'),
      plan(
          id: 'today',
          scheduledFor: now.add(const Duration(hours: 3)),
          location: 'Cinema',
          scheduleStatus: 'AGREED'),
    ], 'me', now: now);

    expect(selected?.plan.id, 'today');
    expect(selected?.type, HomeWatchPlanStateType.today);
  });

  test('cancelled plans are excluded', () {
    expect(
      selectHomeWatchPlanState([plan(status: 'cancelled')], 'me', now: now),
      isNull,
    );
  });

  test('attention count excludes informational upcoming plans', () {
    expect(
      homeWatchPlanAttentionCount([
        plan(id: 'invite', status: 'pending', currentUserAccepted: false),
        plan(
            id: 'upcoming',
            scheduledFor: now.add(const Duration(days: 1)),
            location: 'Home',
            scheduleStatus: 'AGREED'),
      ], 'me', now: now),
      1,
    );
  });

  test('past unlogged plan is an amber action', () {
    final selected = selectHomeWatchPlanState([
      plan(
        scheduledFor: now.subtract(const Duration(hours: 1)),
        location: 'Cinema',
        scheduleStatus: 'AGREED',
      ),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.logWatch);
    expect(selected?.colorRole, WatchPlanColorRole.action);
    expect(selected?.actionLabel, 'Log watch');
  });

  test('my logged watch waiting for another person is teal', () {
    final selected = selectHomeWatchPlanState([
      plan(
        scheduledFor: now.subtract(const Duration(hours: 1)),
        location: 'Home',
        scheduleStatus: 'AGREED',
        confirmations: const [
          WatchConfirmation(id: 'mine', userId: 'me', watched: true),
        ],
      ),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.waitingForLogs);
    expect(selected?.colorRole, WatchPlanColorRole.waiting);
    expect(selected?.title, 'Waiting for @Jamie');
  });

  test('completed plan uses the green recap presentation', () {
    final selected = selectHomeWatchPlanState([
      plan(status: 'completed'),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.recap);
    expect(selected?.colorRole, WatchPlanColorRole.complete);
    expect(selected?.title, 'Your recap is ready');
    expect(selected?.actionLabel, 'View recap');
  });

  test('final movie without a schedule remains an amber action', () {
    final selected = selectHomeWatchPlanState([
      plan(selectedCandidateId: 'one'),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.chooseSchedule);
    expect(selected?.colorRole, WatchPlanColorRole.action);
  });
}
