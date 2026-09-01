import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WatchRequest reminder title uses the selected candidate', () {
    final request = WatchRequest.fromJson({
      'id': 'plan-1',
      'requesterId': 'creator-1',
      'recipientId': 'friend-1',
      'status': 'scheduled',
      'type': 'MOVIE_WATCH_REQUEST',
      'selectedCandidateId': 'candidate-2',
      'candidates': [
        {
          'id': 'candidate-1',
          'movieId': 1,
          'mediaType': 'movie',
          'addedByUserId': 'creator-1',
          'movie': {'id': 1, 'title': 'First choice'},
        },
        {
          'id': 'candidate-2',
          'movieId': 2,
          'mediaType': 'movie',
          'addedByUserId': 'friend-1',
          'movie': {'id': 2, 'title': 'Selected movie'},
        },
      ],
    });

    expect(request.movie, isNull);
    expect(request.watchPlanTitle, 'Selected movie');
  });

  group('WatchRequest', () {
    test('analytics participants include the creator and direct friend', () {
      final request = WatchRequest.fromJson({
        'id': 'wr-direct',
        'requesterId': 'u-1',
        'recipientId': 'u-2',
        'status': 'open',
        'type': 'MOVIE_WATCH_REQUEST',
        'movieId': 42,
      });

      expect(request.analyticsPlanType, 'friend');
      expect(request.analyticsParticipantCount, 2);
      expect(request.analyticsContentId, 42);
    });

    test('show requests expose their actual analytics content type and id', () {
      final request = WatchRequest.fromJson({
        'id': 'wr-show',
        'requesterId': 'u-1',
        'recipientId': 'u-2',
        'status': 'open',
        'type': 'SHOW_WATCH_REQUEST',
        'showId': 99,
      });

      expect(request.analyticsContentType, 'show');
      expect(request.analyticsContentId, 99);
    });
    test('parses independently optional proposed time and location', () {
      final request = WatchRequest.fromJson({
        'id': 'request-1',
        'type': 'MOVIE_WATCH_REQUEST',
        'status': 'open',
        'proposedDate': '2026-08-01T18:30:00.000Z',
        'location': 'Odeon Leicester Square',
      });

      expect(request.proposedDate, DateTime.utc(2026, 8, 1, 18, 30));
      expect(request.location, 'Odeon Leicester Square');

      final locationOnly = WatchRequest.fromJson({
        'id': 'request-2',
        'type': 'MOVIE_WATCH_REQUEST',
        'status': 'open',
        'location': 'My place',
      });
      expect(locationOnly.proposedDate, isNull);
      expect(locationOnly.location, 'My place');
    });

    test('parses location attached to a schedule proposal', () {
      final request = WatchRequest.fromJson({
        'id': 'request-with-plan',
        'type': 'MOVIE_WATCH_REQUEST',
        'status': 'ACCEPTED',
        'scheduleStatus': 'PROPOSED',
        'scheduleProposals': [
          {
            'id': 'proposal-1',
            'proposerId': 'user-1',
            'proposedFor': '2026-08-01T18:30:00.000Z',
            'location': 'Odeon Leicester Square',
            'status': 'PENDING',
          },
        ],
      });

      expect(request.latestPendingProposal?.location, 'Odeon Leicester Square');
    });
    test('parses group and conversation context', () {
      final request = WatchRequest.fromJson({
        'id': 'group-request',
        'status': 'accepted',
        'conversationId': 'conversation-1',
        'group': {'id': 'group-1', 'name': 'Film Club'},
      });

      expect(request.groupId, 'group-1');
      expect(request.groupName, 'Film Club');
      expect(request.conversationId, 'conversation-1');
    });
    test('parses accepted lifecycle response with participants', () {
      final request = WatchRequest.fromJson({
        'id': 'wr-1',
        'status': 'accepted',
        'movieId': 550,
        'movie': {
          'id': 550,
          'title': 'Fight Club',
          'posterPath': '/poster.jpg',
        },
        'createdBy': {
          'id': 'u-1',
          'username': 'laura',
        },
        'acceptedAt': '2026-06-12T18:30:00.000Z',
        'lastActivityAt': '2026-06-12T18:30:00.000Z',
        'hasCurrentUserAccepted': true,
        'canSchedule': true,
        'participants': [
          {
            'user': {'id': 'u-1', 'username': 'laura'},
            'response': 'accepted',
            'respondedAt': '2026-06-12T18:00:00.000Z',
          },
          {
            'user': {'id': 'u-2', 'username': 'sean'},
            'response': 'accepted',
            'respondedAt': '2026-06-12T18:30:00.000Z',
          },
        ],
      });

      expect(request.isAccepted, isTrue);
      expect(request.movie?.title, 'Fight Club');
      expect(request.acceptedAt, isA<DateTime>());
      expect(request.hasCurrentUserAccepted, isTrue);
      expect(request.canScheduleFor('u-1'), isTrue);
      expect(request.participants, hasLength(2));
      expect(request.otherUser('u-1')?.username, 'sean');
    });

    test('marks accepted requests without a schedule as awaiting approval', () {
      final request = WatchRequest.fromJson({
        'id': 'wr-awaiting-schedule',
        'status': 'accepted',
        'scheduleStatus': 'NONE',
      });

      expect(request.isAwaitingScheduleApproval, isTrue);
      expect(request.displayStatusLabel, 'Accepted · scheduling in progress');
    });

    test('marks accepted proposed schedules as awaiting approval', () {
      final request = WatchRequest.fromJson({
        'id': 'wr-proposed-schedule',
        'status': 'accepted',
        'scheduleStatus': 'PROPOSED',
      });

      expect(request.isAwaitingScheduleApproval, isTrue);
      expect(request.displayStatusLabel, 'Accepted · scheduling in progress');
    });

    test('marks a newly created dated plan as scheduling in progress', () {
      final request = WatchRequest.fromJson({
        'id': 'wr-dated-invite',
        'status': 'PENDING',
        'scheduleStatus': 'NONE',
        'proposedDate': '2026-09-01T00:00:00.000Z',
      });

      expect(request.isAwaitingScheduleApproval, isTrue);
      expect(request.displayStatusLabel, 'Scheduling in progress');
    });

    test('does not expose a first movie before multi-option choices lock in',
        () {
      final request = WatchRequest.fromJson({
        'id': 'wr-movie-options',
        'movieId': 101,
        'movie': {'id': 101, 'title': 'Incorrect first option'},
        'candidates': [
          {'id': 'option-1', 'movieId': 101, 'title': 'Option one'},
          {'id': 'option-2', 'movieId': 202, 'title': 'Option two'},
        ],
      });

      expect(request.movie, isNull);
      expect(request.movieId, isNull);
    });

    test('keeps the selected movie visible after multi-option choices lock in',
        () {
      final request = WatchRequest.fromJson({
        'id': 'wr-movie-selected',
        'movieId': 202,
        'movie': {'id': 202, 'title': 'Selected option'},
        'selectedCandidateId': 'option-2',
        'candidates': [
          {'id': 'option-1', 'movieId': 101, 'title': 'Option one'},
          {'id': 'option-2', 'movieId': 202, 'title': 'Selected option'},
        ],
      });

      expect(request.movie?.title, 'Selected option');
      expect(request.movieId, 202);
    });

    test('maps lifecycle and per-user actions to Watch Plan stages', () {
      final invitation = WatchRequest.fromJson({
        'id': 'invite',
        'requesterId': 'jamie',
        'recipientId': 'laura',
        'status': 'PENDING',
      });
      final scheduled = WatchRequest.fromJson({
        'id': 'scheduled',
        'status': 'SCHEDULED',
        'scheduleStatus': 'AGREED',
        'scheduledFor': '2026-08-20T20:00:00.000Z',
      });
      final past = WatchRequest.fromJson({
        'id': 'past',
        'status': 'COMPLETED',
        'watchedStatus': 'WATCHED',
      });

      expect(invitation.planStageFor('laura'), WatchPlanStage.needsReply);
      expect(
          invitation.planStageFor('jamie'), WatchPlanStage.waitingForReplies);
      expect(
        scheduled.planStageFor('laura', now: DateTime.utc(2026, 8, 15)),
        WatchPlanStage.upcoming,
      );
      expect(past.planStageFor('laura'), WatchPlanStage.past);
      expect(WatchPlanStage.planning.primaryActionLabel, 'Continue planning');
    });

    test('parses scheduled and completed fields safely', () {
      final scheduled = WatchRequest.fromJson({
        'id': 'wr-2',
        'requesterId': 'u-1',
        'recipientId': 'u-2',
        'status': 'scheduled',
        'scheduledFor': '2026-06-13T19:30:00.000Z',
        'canComplete': true,
      });
      final completed = WatchRequest.fromJson({
        'id': 'wr-3',
        'requesterId': 'u-1',
        'recipientId': 'u-2',
        'status': 'completed',
        'completedAt': '2026-06-13T22:00:00.000Z',
        'participants': [
          {
            'user': {'id': 'u-1', 'username': 'laura'},
            'response': 'accepted',
            'watchedAt': '2026-06-13T21:55:00.000Z',
            'rating': 8,
            'reviewText': 'Great night.',
          },
        ],
      });

      expect(scheduled.isScheduled, isTrue);
      expect(scheduled.canProposeSchedule, isTrue);
      expect(scheduled.scheduledFor, isA<DateTime>());
      expect(scheduled.canCompleteFor('u-2'), isTrue);
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isA<DateTime>());
      expect(completed.participantFor('u-1')?.rating, 8);
      expect(completed.participantFor('u-1')?.reviewText, 'Great night.');
    });

    test('normalizes legacy lifecycle statuses', () {
      final pending = WatchRequest.fromJson({
        'id': 'wr-4',
        'status': 'pending',
      });
      final finalised = WatchRequest.fromJson({
        'id': 'wr-5',
        'status': 'finalised',
      });

      expect(pending.isPending, isTrue);
      expect(finalised.isCompleted, isTrue);
    });

    test('parses direct scheduling lifecycle fields', () {
      final request = WatchRequest.fromJson({
        'id': 'wr-7',
        'type': 'SHOW_WATCH_REQUEST',
        'status': 'ACCEPTED',
        'scheduleStatus': 'PROPOSED',
        'watchedStatus': 'NOT_DUE',
        'scheduleProposals': [
          {
            'id': 'proposal-old',
            'proposerId': 'u-1',
            'proposedFor': '2026-06-20T18:00:00.000Z',
            'status': 'PENDING',
            'createdAt': '2026-06-12T12:00:00.000Z',
          },
          {
            'id': 'proposal-new',
            'proposerId': 'u-2',
            'proposedFor': '2026-06-20T19:30:00.000Z',
            'status': 'PENDING',
            'createdAt': '2026-06-12T13:00:00.000Z',
          },
        ],
        'watchConfirmations': [
          {
            'id': 'confirm-1',
            'userId': 'u-1',
            'watched': true,
            'rating': 8,
          },
        ],
        'needsWatchConfirmation': true,
      });

      expect(request.isWatchRequest, isTrue);
      expect(request.canProposeSchedule, isTrue);
      expect(request.latestPendingProposal?.id, 'proposal-new');
      expect(request.canRespondToProposal('u-1'), isTrue);
      expect(request.hasCurrentUserConfirmed('u-1'), isTrue);
      expect(request.canConfirmWatchedFor('u-2'), isTrue);
    });
  });

  group('WatchRequestState', () {
    test('copies top-level confirmation flag onto parsed request', () {
      final state = WatchRequestState.fromJson({
        'needsWatchConfirmation': true,
        'request': {
          'id': 'wr-state',
          'type': 'MOVIE_WATCH_REQUEST',
          'status': 'ACCEPTED',
        },
      });

      expect(state.needsWatchConfirmation, isTrue);
      expect(state.request.needsWatchConfirmation, isTrue);
      expect(state.request.canConfirmWatchedFor('u-1'), isTrue);
    });
  });

  group('WatchRequestStatus', () {
    test('supports accepted lifecycle status', () {
      expect(
        WatchRequestStatus.fromString('accepted'),
        WatchRequestStatus.accepted,
      );
      expect(WatchRequestStatus.accepted.apiValue, 'accepted');
      expect(WatchRequestStatus.accepted.statusLabel, 'Accepted');
    });

    test('maps legacy API status values', () {
      expect(WatchRequestStatus.fromString('pending'), WatchRequestStatus.open);
      expect(
        WatchRequestStatus.fromString('finalised'),
        WatchRequestStatus.completed,
      );
    });
  });

  group('GroupWatchRequest', () {
    test('parses computed capability fields', () {
      final request = GroupWatchRequest.fromJson({
        'id': 'wr-6',
        'pgGroupRequestId': 'pg-wr-6',
        'conversationId': 'conv-1',
        'createdById': 'u-1',
        'status': 'scheduled',
        'hasCurrentUserAccepted': true,
        'hasCurrentUserCompleted': false,
        'canSchedule': true,
        'canComplete': true,
        'canCancel': false,
      });

      expect(request.hasCurrentUserAccepted, isTrue);
      expect(request.canScheduleFor('u-2'), isTrue);
      expect(request.canCompleteFor('u-2'), isTrue);
      expect(request.canCancelFor('u-2'), isFalse);
      expect(request.matchesId('wr-6'), isTrue);
      expect(request.matchesId('pg-wr-6'), isTrue);
      expect(request.matchesId('another-request'), isFalse);
    });
  });
}
