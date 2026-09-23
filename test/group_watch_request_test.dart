import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backdrop uses selected movie and stays hidden while choosing', () {
    final data = <String, dynamic>{
      'id': 'plan',
      'movie': {'id': 1, 'backdropUrl': '/old.jpg'},
      'candidates': [
        {
          'id': 'a',
          'movie': {'id': 1, 'backdropUrl': '/first.jpg'}
        },
        {
          'id': 'b',
          'movie': {'id': 2, 'backdropUrl': '/selected.jpg'}
        },
      ],
    };
    expect(GroupWatchRequest.fromJson(data).selectedBackdropPath, isNull);
    expect(
        GroupWatchRequest.fromJson({...data, 'selectedCandidateId': 'b'})
            .selectedBackdropPath,
        '/selected.jpg');
    expect(
        GroupWatchRequest.fromJson({
          'id': 'single',
          'movie': {'id': 1, 'backdropUrl': '/single.jpg'}
        }).selectedBackdropPath,
        '/single.jpg');
  });

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
