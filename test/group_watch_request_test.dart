import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
