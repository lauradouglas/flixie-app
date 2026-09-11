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
  DateTime? proposedDate,
  String? location,
  String? groupName,
  String? groupId,
  String? selectedCandidateId,
  List<WatchRequestParticipant> participants = const [],
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
      proposedDate: proposedDate,
      location: location,
      groupName: groupName,
      groupId: groupId,
      selectedCandidateId: selectedCandidateId,
      participants: participants,
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

  test('saved group picks wait for the group rather than one named friend', () {
    final selected = selectHomeWatchPlanState([
      plan(groupId: 'group', groupName: 'Movie crew', candidates: [
        candidate('one', selectedBy: ['me']),
        candidate('two', selectedBy: ['me']),
      ]),
    ], 'me', now: now);
    expect(selected?.type, HomeWatchPlanStateType.waitingForChoices);
    expect(selected?.title, 'Waiting for the group’s picks');
  });

  test('a missed group screening is not labelled as a logged viewing', () {
    final selected = selectHomeWatchPlanState([
      plan(
          groupName: 'Film club',
          groupId: 'group',
          selectedCandidateId: 'chosen',
          scheduleStatus: 'AGREED',
          scheduledFor: now.subtract(const Duration(hours: 2)),
          location: 'Cinema',
          confirmations: const [
            WatchConfirmation(id: 'missed', userId: 'me', watched: false),
          ]),
    ], 'me', now: now);
    expect(selected?.eyebrow, 'YOU DIDN’T MAKE IT');
    expect(selected?.requiresAttention, isFalse);
    expect(selected?.actionLabel, 'View plan');
  });

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
    expect(selected?.title, 'Inception');
    expect(selected?.eyebrow, 'STARTS IN 3 HOURS');
    expect(selected?.supportingText, contains('Scheduled'));
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

  test('my early logged watch waits for the other person', () {
    final selected = selectHomeWatchPlanState([
      plan(
        scheduledFor: now.add(const Duration(hours: 1)),
        location: 'Home',
        scheduleStatus: 'AGREED',
        confirmations: const [
          WatchConfirmation(id: 'mine', userId: 'me', watched: true),
        ],
      ),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.waitingForLogs);
    expect(selected?.eyebrow, 'YOUR WATCH IS LOGGED');
  });

  test('everyone logging early opens the recap instead of the countdown', () {
    final selected = selectHomeWatchPlanState([
      plan(
        scheduledFor: now.add(const Duration(hours: 1)),
        location: 'Cinema',
        scheduleStatus: 'AGREED',
        confirmations: const [
          WatchConfirmation(id: 'mine', userId: 'me', watched: true),
          WatchConfirmation(id: 'theirs', userId: 'jamie', watched: true),
        ],
      ),
    ], 'me', now: now);

    expect(selected?.type, HomeWatchPlanStateType.recap);
    expect(selected?.eyebrow, 'EVERYONE WATCHED');
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

  test('confirmed group slot ignores stale proposal with a declined invitee', () {
    final slot = now.add(const Duration(days: 3));
    final request = plan(
      groupId: 'group', groupName: 'Friday films', status: 'scheduled',
      scheduledFor: slot, scheduleStatus: 'AGREED', location: 'Cinema',
      selectedCandidateId: 'one',
      participants: const [
        WatchRequestParticipant(user: me, response: 'ACCEPTED'),
        WatchRequestParticipant(user: jamie, response: 'ACCEPTED'),
        WatchRequestParticipant(user: WatchRequestUser(id: 'declined', username: 'Declined'), response: 'DECLINED'),
      ],
      proposals: [WatchScheduleProposal(id: 'old', proposerId: 'jamie',
        proposedFor: slot, location: 'Cinema', status: 'PENDING', responses: const [
          WatchScheduleProposalResponse(userId: 'me', status: 'ACCEPTED'),
          WatchScheduleProposalResponse(userId: 'jamie', status: 'ACCEPTED'),
          WatchScheduleProposalResponse(userId: 'declined', status: 'PENDING'),
        ])],
    );
    expect(request.latestPendingProposal, isNull);
    for (final userId in ['me', 'jamie']) {
      final selected = selectHomeWatchPlanState([request], userId, now: now);
      expect(selected?.type, isNot(HomeWatchPlanStateType.waitingForScheduleApproval));
      expect(selected?.type, isNot(HomeWatchPlanStateType.reviewSchedule));
      expect(selected?.requiresAttention, isFalse);
    }
  });

  test('group creator waits for approval after suggesting a time', () {
    final selected = selectHomeWatchPlanState([
      plan(
        requesterId: 'me',
        groupName: 'Friday films',
        selectedCandidateId: 'one',
        proposedDate: now.add(const Duration(days: 1)),
      ),
    ], 'me', now: now);

    expect(
      selected?.type,
      HomeWatchPlanStateType.waitingForScheduleApproval,
    );
    expect(selected?.requiresAttention, isFalse);
    expect(selected?.actionLabel, 'View plan');
  });

  test('group member waits after approving a proposed time', () {
    final selected = selectHomeWatchPlanState([
      plan(
        groupName: 'Friday films',
        selectedCandidateId: 'one',
        proposals: [
          WatchScheduleProposal(
            id: 'proposal',
            proposerId: 'jamie',
            proposedFor: now.add(const Duration(days: 1)),
            responses: const [
              WatchScheduleProposalResponse(
                userId: 'me',
                status: 'ACCEPTED',
              ),
            ],
          ),
        ],
      ),
    ], 'me', now: now);

    expect(
      selected?.type,
      HomeWatchPlanStateType.waitingForScheduleApproval,
    );
    expect(selected?.requiresAttention, isFalse);
  });

  test('resolved group replies use green, amber, and red outcomes', () {
    WatchRequestParticipant response(String id, String status) =>
        WatchRequestParticipant(
            user: WatchRequestUser(id: id, username: id), response: status);

    final everyoneIn = selectHomeWatchPlanState([
      plan(
        status: 'open',
        groupId: 'group',
        groupName: 'Friday films',
        participants: [
          response('me', 'ACCEPTED'),
          response('jamie', 'ACCEPTED')
        ],
      ),
    ], 'me', now: now);
    final someIn = selectHomeWatchPlanState([
      plan(
        groupId: 'group',
        groupName: 'Friday films',
        participants: [
          response('me', 'ACCEPTED'),
          response('jamie', 'DECLINED')
        ],
      ),
    ], 'me', now: now);
    final nobodyIn = selectHomeWatchPlanState([
      plan(
        requesterId: 'me',
        groupId: 'group',
        groupName: 'Friday films',
        participants: [response('jamie', 'DECLINED')],
      ),
    ], 'me', now: now);

    expect(everyoneIn?.colorRole, WatchPlanColorRole.complete);
    expect(someIn?.colorRole, WatchPlanColorRole.action);
    expect(nobodyIn?.colorRole, WatchPlanColorRole.failed);
  });
}
