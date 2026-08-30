import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/watch_request.dart';

void main() {
  group('friend Watch Plan lifecycle contract', () {
    test('each participant receives the appropriate next action', () {
      final invite = WatchRequest.fromJson({
        'id': 'invite',
        'requesterId': 'laura',
        'recipientId': 'jamie',
        'status': 'PENDING',
      });
      final proposed = WatchRequest.fromJson({
        'id': 'proposal',
        'requesterId': 'laura',
        'recipientId': 'jamie',
        'status': 'ACCEPTED',
        'scheduleStatus': 'PROPOSED',
        'scheduleProposals': [
          {
            'id': 'schedule-1',
            'proposerId': 'laura',
            'proposedFor': '2026-09-01T20:00:00.000Z',
            'status': 'PENDING',
            'createdAt': '2026-08-30T12:00:00.000Z',
          },
        ],
      });

      expect(invite.planStageFor('jamie'), WatchPlanStage.needsReply);
      expect(invite.planStageFor('laura'), WatchPlanStage.waitingForReplies);
      expect(proposed.planStageFor('jamie'), WatchPlanStage.needsReply);
      expect(proposed.planStageFor('laura'), WatchPlanStage.waitingForReplies);
    });

    test('the scheduled boundary moves a plan from upcoming to past', () {
      final request = WatchRequest.fromJson({
        'id': 'scheduled',
        'status': 'SCHEDULED',
        'scheduleStatus': 'AGREED',
        'scheduledFor': '2026-09-01T20:00:00.000Z',
      });

      expect(
        request.planStageFor('laura', now: DateTime.utc(2026, 9, 1, 19, 59)),
        WatchPlanStage.upcoming,
      );
      expect(
        request.planStageFor('laura', now: DateTime.utc(2026, 9, 1, 20)),
        WatchPlanStage.past,
      );
    });

    test('only the newest pending schedule proposal is actionable', () {
      final request = WatchRequest.fromJson({
        'id': 'reschedule',
        'status': 'ACCEPTED',
        'scheduleStatus': 'PROPOSED',
        'scheduleProposals': [
          {
            'id': 'old',
            'proposerId': 'laura',
            'proposedFor': '2026-09-01T19:00:00.000Z',
            'status': 'PENDING',
            'createdAt': '2026-08-30T12:00:00.000Z',
          },
          {
            'id': 'current',
            'proposerId': 'jamie',
            'proposedFor': '2026-09-01T20:00:00.000Z',
            'status': 'PENDING',
            'createdAt': '2026-08-30T13:00:00.000Z',
          },
        ],
      });

      expect(request.latestPendingProposal?.id, 'current');
      expect(request.canRespondToProposal('laura'), isTrue);
      expect(request.canRespondToProposal('jamie'), isFalse);
    });

    test('watch confirmations retain independent ratings and notes', () {
      final request = WatchRequest.fromJson({
        'id': 'logged',
        'status': 'SCHEDULED',
        'watchConfirmations': [
          {
            'id': 'laura-watch',
            'userId': 'laura',
            'watched': true,
            'rating': 9,
            'reviewText': 'Loved it.',
          },
          {
            'id': 'jamie-watch',
            'userId': 'jamie',
            'watched': true,
            'rating': 7,
          },
        ],
      });

      final laura = request.watchConfirmations
          .firstWhere((confirmation) => confirmation.userId == 'laura');
      final jamie = request.watchConfirmations
          .firstWhere((confirmation) => confirmation.userId == 'jamie');
      expect(laura.rating, 9);
      expect(laura.reviewText, 'Loved it.');
      expect(jamie.rating, 7);
    });
  });

  group('group Watch Plan contract', () {
    test('accepted members can complete while declined members cannot', () {
      final request = GroupWatchRequest.fromJson({
        'id': 'group-plan',
        'conversationId': 'film-club',
        'createdById': 'laura',
        'status': 'scheduled',
        'responses': [
          {'memberId': 'jamie', 'status': 'ACCEPTED'},
          {'memberId': 'mat', 'status': 'DECLINED'},
        ],
      });

      expect(request.canCompleteFor('jamie'), isTrue);
      expect(request.canCompleteFor('mat'), isFalse);
      expect(request.analyticsParticipantCount, 3);
    });

    test('creator controls scheduling and cancellation by default', () {
      final request = GroupWatchRequest.fromJson({
        'id': 'group-plan',
        'conversationId': 'film-club',
        'createdById': 'laura',
        'status': 'accepted',
      });

      expect(request.canScheduleFor('laura'), isTrue);
      expect(request.canCancelFor('laura'), isTrue);
      expect(request.canCancelFor('jamie'), isFalse);
    });

    test('expired and terminal group plans reject further responses', () {
      final expired = GroupWatchRequest.fromJson({
        'id': 'expired',
        'conversationId': 'film-club',
        'createdById': 'laura',
        'status': 'expired',
      });
      final completed = GroupWatchRequest.fromJson({
        'id': 'completed',
        'conversationId': 'film-club',
        'createdById': 'laura',
        'status': 'completed',
      });

      expect(expired.canRespond, isFalse);
      expect(completed.canRespond, isFalse);
      expect(completed.isArchived, isTrue);
    });
  });
}
