import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversation plans preserve both identifiers and their message link',
      () {
    final request = GroupWatchRequest.fromJson({
      'id': 'conversation-plan',
      'pgGroupRequestId': 'database-plan',
      'linkedMessageId': 'timeline-message',
      'conversationId': 'chat',
      'createdBy': 'creator',
      'status': 'scheduled',
    });
    expect(request.matchesId('conversation-plan'), isTrue);
    expect(request.matchesId('database-plan'), isTrue);
    expect(request.linkedMessageId, 'timeline-message');
    expect(request.userId, 'creator');
    expect(request.status, WatchRequestStatus.scheduled);
  });

  test('parses nested schedule proposal participants', () {
    final request = GroupWatchRequest.fromJson({
      'id': 'request',
      'groupId': 'group',
      'createdById': 'creator',
      'scheduleProposals': [
        {
          'id': 'proposal',
          'proposer': {'id': 'proposer'},
          'proposedFor': '2026-09-07T20:00:00.000Z',
          'status': 'pending',
          'responses': [
            {
              'user': {'id': 'proposer'},
              'decision': 'accepted',
            },
          ],
        },
      ],
    });

    final proposal = request.activeScheduleProposal;
    expect(proposal?.proposerId, 'proposer');
    expect(proposal?.responseFor('proposer')?.status, 'accepted');
  });
}
