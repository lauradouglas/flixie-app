import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/models/group_watch_request.dart';

void main() {
  test('direct plan state supplies chat status, participants and badge data',
      () {
    final plan = RequestService.chatPlanFromState({
      'request': {
        'id': 'friend-plan',
        'requesterId': 'creator',
        'status': 'accepted',
        'movie': {'title': 'Spider-Man', 'posterPath': '/poster.jpg'},
        'participants': [
          {
            'user': {
              'id': 'friend',
              'username': 'Jamie',
              'profileBadges': ['founder']
            },
            'response': 'accepted'
          },
        ],
        'scheduleProposals': [
          {
            'id': 'time',
            'proposerId': 'creator',
            'status': 'PENDING',
            'proposedFor': '2026-10-01T19:00:00Z'
          },
        ],
      },
    }, 'friend');
    expect(plan.id, 'friend-plan');
    expect(plan.status, WatchRequestStatus.accepted);
    expect(plan.movieTitle, 'Spider-Man');
    expect(plan.currentUserResponse, WatchResponseDecision.accepted);
    expect(plan.memberStatuses.single.profileBadges, ['founder']);
    expect(plan.activeScheduleProposal?.id, 'time');
  });
}
