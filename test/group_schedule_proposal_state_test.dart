import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/group_watch_request.dart';

void main() {
  GroupWatchRequest plan(String? scheduled, String proposed, {String? location}) =>
      GroupWatchRequest(id: 'plan', groupId: 'group', userId: 'creator',
        scheduledFor: scheduled, location: 'Cinema', scheduleProposals: [
          GroupScheduleProposal(id: 'proposal', proposerId: 'creator',
            proposedFor: proposed, status: 'PENDING', location: location),
        ]);
  test('confirmed initial slot does not become a time change', () {
    expect(plan('2026-09-11T14:25:00Z', '2026-09-11T15:25:00+01:00', location: 'Cinema').activeScheduleProposal, isNull);
  });
  test('different time or location still needs review', () {
    expect(plan('2026-09-11T14:25:00Z', '2026-09-11T15:25:00Z').activeScheduleProposal, isNotNull);
    expect(plan('2026-09-11T14:25:00Z', '2026-09-11T14:25:00Z', location: 'Home').activeScheduleProposal, isNotNull);
  });
  test('unconfirmed initial time remains available to accept', () {
    expect(plan(null, '2026-09-11T14:25:00Z').activeScheduleProposal, isNotNull);
  });
}
